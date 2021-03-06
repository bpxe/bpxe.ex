defmodule BPXETest.BPMN do
  use ExUnit.Case, async: true
  alias BPXE.Engine.Model
  doctest BPXE.BPMN

  test "parsing sample" do
    {:ok, pid} = BPXE.Engine.Models.start_model()

    {:ok, _} =
      BPXE.BPMN.parse_stream(File.stream!(Path.join(__DIR__, "/files/sample.bpmn")),
        model: pid
      )
  end

  test "should interpolate expressions in bpxe:json and output results as JSON" do
    {:ok, pid} = BPXE.Engine.Models.start_model()

    {:ok, _} =
      BPXE.BPMN.parse_stream(File.stream!(Path.join(__DIR__, "/files/interpolation.bpmn")),
        model: pid
      )

    model = Model.model(pid)

    expr = Warpath.query!(model, "$.process.startEvent.extensionElements.:json.:body")

    assert is_function(expr)
    assert expr.(fn "test" -> %{"b" => "c"} end) == {:ok, %{"a" => %{"b" => "c"}}}
  end

  test "should interpolate expressions in XSL JSON and output results as strings (only primitive types allowed)" do
    {:ok, pid} = BPXE.Engine.Models.start_model()

    {:ok, _} =
      BPXE.BPMN.parse_stream(File.stream!(Path.join(__DIR__, "/files/interpolation.bpmn")),
        model: pid
      )

    model = Model.model(pid)

    expr = Warpath.query!(model, "$.process.endEvent.extensionElements.:json.:body")

    assert is_function(expr)

    assert expr.(fn
             "a" -> 3
             "b" -> true
           end) == %{"test" => 3, "hello" => "3", "hey" => true}
  end
end
