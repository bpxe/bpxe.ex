defmodule BPXE.Engine.PrecedenceGateway do
  @moduledoc """
  *Note: This gateway is not described in BPMN 2.0. Currently it can only be
  added programmatically (not through BPMN XML document, at this time)*

  This gateway will only process the first model of a received token
  (tracked by token_id) and send it out to a corresponding output. The
  correspondance is achieved by requiring the same number of incoming and
  outgoing sequence flows and they will be mapped directly, so that Nth incoming
  flow will trigger Nth outgoing flow.
  """
  use GenServer
  use BPXE.Engine.FlowNode
  use BPXE.Engine.Model.Recordable
  alias BPXE.Engine.Process
  alias BPXE.Engine.Process.Log

  defstate precedence: %{}

  @persist_state :precedence

  def start_link(id, options, model, process) do
    GenServer.start_link(__MODULE__, {id, options, model, process})
  end

  def init({id, options, model, process}) do
    state =
      %__MODULE__{}
      |> put_state(Base, %{id: id, options: options, model: model, process: process})

    state = initialize(state)
    {:ok, state}
  end

  def handle_token({%BPXE.Token{} = token, id}, state) do
    base_state = get_state(state, BPXE.Engine.Base)

    Process.log(base_state.process, %Log.PrecedenceGatewayActivated{
      pid: self(),
      id: base_state.id,
      token_id: token.token_id
    })

    case state.precedence[token.token_id] do
      nil ->
        Process.log(base_state.process, %Log.PrecedenceGatewayPrecedenceEstablished{
          pid: self(),
          id: base_state.id,
          token_id: token.token_id
        })

        state = %{state | precedence: Map.put(state.precedence, token.token_id, [id])}

        case corresponds_to(id, state) do
          nil ->
            # There's no mapping between these flows
            # Drop the token
            {:dontsend, state}

          outgoing ->
            # There's a mapping, send it there
            {:send, token, [outgoing], state}
        end

      precedence ->
        Process.log(base_state.process, %Log.PrecedenceGatewayTokenDiscarded{
          pid: self(),
          id: base_state.id,
          token_id: token.token_id
        })

        new_precedence = [id | precedence]

        flow_node_state = get_state(state, BPXE.Engine.FlowNode)

        if length(new_precedence) == length(flow_node_state.incoming) ==
             length(flow_node_state.outgoing) do
          # We've received them all, drop it from the state
          {:dontsend, %{state | precedence: Map.delete(state.precedence, token.token_id)}}
        else
          # Drop the token
          {:dontsend,
           %{state | precedence: Map.put(state.precedence, token.token_id, new_precedence)}}
        end
    end
  end

  defp corresponds_to(id, state) do
    flow_node_state = get_state(state, BPXE.Engine.FlowNode)
    index = Enum.find_index(flow_node_state.incoming, fn x -> x == id end)
    Enum.at(flow_node_state.outgoing, index)
  end
end
