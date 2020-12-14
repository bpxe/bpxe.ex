defmodule BPEXETest.BPMN do
  use ExUnit.Case
  doctest BPEXE.BPMN

  test "parsing sample" do
    {:ok, _} = BPEXE.BPMN.parse_stream(File.stream!(Path.join(__DIR__, "/files/sample.bpmn")))
  end
end