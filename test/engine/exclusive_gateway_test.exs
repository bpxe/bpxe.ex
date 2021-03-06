defmodule BPXETest.Engine.ExclusiveGateway do
  use ExUnit.Case, async: true
  alias BPXE.Engine.{Model, Process, SequenceFlow}
  alias Process.Log
  doctest BPXE.Engine.ExclusiveGateway

  @xsi "http://www.w3.org/2001/XMLSchema-instance"
  test "sequence flow with the first truthful condition proceeds" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, the_end} = Process.add_end_event(proc1, id: "end")

    {:ok, another_end} = Process.add_end_event(proc1, id: "anotherEnd")

    {:ok, gw} = Process.add_exclusive_gateway(proc1, id: "gw")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, gw)

    {:ok, sf_true} = Process.establish_sequence_flow(proc1, "true", gw, the_end)
    {:ok, sf_true2} = Process.establish_sequence_flow(proc1, "true2", gw, another_end)

    SequenceFlow.add_condition_expression(
      sf_true,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`true`"
    )

    SequenceFlow.add_condition_expression(
      sf_true2,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`true`"
    )

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.EventActivated{id: "start"}})
    assert_receive({Log, %Log.EventActivated{id: "end"}})
    refute_receive({Log, %Log.EventActivated{id: "anotherEnd"}})
  end

  test "sequence flow with the default case proceeds if no other matches" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, the_end} = Process.add_end_event(proc1, id: "end")

    {:ok, another_end} = Process.add_end_event(proc1, id: "anotherEnd")

    {:ok, gw} = Process.add_exclusive_gateway(proc1, id: "gw")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, gw)

    {:ok, sf_false} = Process.establish_sequence_flow(proc1, "false", gw, the_end)
    {:ok, sf_false2} = Process.establish_sequence_flow(proc1, "false2", gw, the_end)
    {:ok, _sf_default} = Process.establish_sequence_flow(proc1, "default", gw, another_end)

    SequenceFlow.add_condition_expression(
      sf_false,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    SequenceFlow.add_condition_expression(
      sf_false2,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.EventActivated{id: "start"}})
    assert_receive({Log, %Log.EventActivated{id: "anotherEnd"}})
    refute_receive({Log, %Log.EventActivated{id: "end"}})
  end

  test "sequence flow with the default case does not proceed if other matches, even if it was added before" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, the_end} = Process.add_end_event(proc1, id: "end")

    {:ok, another_end} = Process.add_end_event(proc1, id: "anotherEnd")

    {:ok, gw} = Process.add_exclusive_gateway(proc1, id: "gw")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, gw)

    {:ok, _sf_default} = Process.establish_sequence_flow(proc1, "default", gw, another_end)
    {:ok, sf_false} = Process.establish_sequence_flow(proc1, "false", gw, the_end)
    {:ok, sf_true} = Process.establish_sequence_flow(proc1, "true", gw, the_end)

    SequenceFlow.add_condition_expression(
      sf_false,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    SequenceFlow.add_condition_expression(
      sf_true,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`true`"
    )

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.EventActivated{id: "start"}})
    assert_receive({Log, %Log.EventActivated{id: "end"}})
    refute_receive({Log, %Log.EventActivated{id: "anotherEnd"}})
  end
end
