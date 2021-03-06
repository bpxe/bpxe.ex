defmodule BPXE.BPMN.JSON do
  import BPXE.BPMN.Interpolation
  defstruct value: nil, current: nil, characters: nil, keyed: false, interpolate: false
  use ExConstructor

  def prepare(%__MODULE__{interpolate: false, value: value}), do: value

  def prepare(%__MODULE__{value: value}) do
    fn cb ->
      interpolate(value, cb)
    end
  end

  def interpolate(value, cb) when is_function(value, 1) do
    value.(cb)
  end

  def interpolate(value, cb) when is_list(value) do
    value |> Enum.map(fn v -> interpolate(v, cb) end)
  end

  def interpolate(value, cb) when is_map(value) do
    value |> Enum.map(fn {k, v} -> {k, interpolate(v, cb)} end) |> Map.new()
  end

  def interpolate(value, _cb), do: value

  def handle_event(
        :start_element,
        {{_, "map"}, args},
        %__MODULE__{current: nil} = state
      )
      when map_size(args) == 0 do
    {:ok, %{state | value: %{}, current: []}}
  end

  def handle_event(
        :start_element,
        {{_, "map"}, args},
        %__MODULE__{current: path, value: value} = state
      )
      when map_size(args) == 0 do
    {:ok, %{state | value: update(value, path, %{})}}
  end

  def handle_event(
        :start_element,
        {{_, _} = element, %{"key" => key}},
        %__MODULE__{current: path} = state
      ) do
    handle_event(:start_element, {element, %{}}, %{state | current: [key | path], keyed: true})
  end

  def handle_event(
        :end_element,
        {_, _} = element,
        %__MODULE__{keyed: true} = state
      ) do
    handle_event(:end_element, element, %{state | keyed: false})
    |> Result.map(fn state -> %{state | current: tl(state.current)} end)
  end

  def handle_event(
        :end_element,
        {_, "map"},
        %__MODULE__{current: current} = state
      )
      when current == [] or is_nil(current) do
    {:ok, %{state | current: nil}}
  end

  def handle_event(
        :end_element,
        {_, "map"},
        %__MODULE__{current: [_ | path]} = state
      ) do
    {:ok, %{state | current: path}}
  end

  def handle_event(
        :start_element,
        {{_, "array"}, _},
        %__MODULE__{current: path, value: value} = state
      ) do
    {:ok, %{state | value: update(value, path, [])}}
  end

  def handle_event(
        :end_element,
        {_, "array"},
        %__MODULE__{value: value, current: path} = state
      ) do
    {:ok, %{state | value: reverse(value, path)}}
  end

  def handle_event(
        :start_element,
        {{_, "number"}, _},
        %__MODULE__{} = state
      ) do
    {:ok, %{state | characters: ""}}
  end

  def handle_event(
        :end_element,
        {_, "number"},
        %__MODULE__{value: value, current: path, characters: characters} = state
      ) do
    case interpolate(characters) do
      characters when is_binary(characters) ->
        number =
          case Integer.parse(characters) do
            {int, ""} ->
              int

            {_, "." <> _} ->
              case Float.parse(characters) do
                {float, _} -> float
              end

            {int, _} ->
              int

            :error ->
              :error
          end

        case number do
          :error ->
            {:error, {:invalid_number, characters}}

          _ ->
            {:ok, %{state | characters: nil, value: update(value, path, number)}}
        end

      f when is_function(f, 1) ->
        {:ok, %{state | characters: nil, value: update(value, path, f), interpolate: true}}
    end
  end

  def handle_event(
        :start_element,
        {{_, "string"}, _},
        %__MODULE__{} = state
      ) do
    {:ok, %{state | characters: ""}}
  end

  def handle_event(
        :end_element,
        {_, "string"},
        %__MODULE__{value: value, current: path, characters: characters} = state
      ) do
    case interpolate(characters) do
      characters when is_binary(characters) ->
        {:ok, %{state | characters: nil, value: update(value, path, characters)}}

      f when is_function(f, 1) ->
        {:ok,
         %{
           state
           | characters: nil,
             value: update(value, path, fn cb -> f.(cb) |> to_string() end),
             interpolate: true
         }}
    end
  end

  def handle_event(
        :start_element,
        {{_, "boolean"}, _},
        %__MODULE__{} = state
      ) do
    {:ok, %{state | characters: ""}}
  end

  def handle_event(
        :end_element,
        {_, "boolean"},
        %__MODULE__{value: value, current: path, characters: characters} = state
      ) do
    case interpolate(characters) do
      characters when is_binary(characters) ->
        bool =
          case characters |> String.trim() do
            "true" -> true
            "false" -> false
          end

        {:ok, %{state | characters: nil, value: update(value, path, bool)}}

      f when is_function(f, 1) ->
        {:ok, %{state | characters: nil, value: update(value, path, f), interpolate: true}}
    end
  end

  def handle_event(
        :start_element,
        {{_, "null"}, _},
        state
      ) do
    {:ok, state}
  end

  def handle_event(
        :end_element,
        {_, "null"},
        %__MODULE__{value: value, current: path} = state
      ) do
    {:ok, %{state | value: update(value, path, nil)}}
  end

  def handle_event(
        :characters,
        chars,
        %__MODULE__{characters: characters} = state
      )
      when not is_nil(characters) do
    {:ok, %{state | characters: characters <> chars}}
  end

  def handle_event(
        :characters,
        _,
        %__MODULE__{} = state
      ) do
    {:ok, state}
  end

  defp reverse(value, nil), do: Enum.reverse(value)
  defp reverse(value, []), do: Enum.reverse(value)
  defp reverse(value, path), do: update_in(value, path, fn _ -> Enum.reverse(value) end)

  defp update(list, nothing, new_value)
       when (is_nil(nothing) or nothing == []) and is_list(list) do
    [new_value | list]
  end

  defp update(_value, nothing, new_value) when is_nil(nothing) or nothing == [] do
    new_value
  end

  defp update(value, path, new_value) do
    update_in(value, path |> Enum.reverse(), fn
      list when is_list(list) ->
        [new_value | list]

      _ ->
        new_value
    end)
  end
end
