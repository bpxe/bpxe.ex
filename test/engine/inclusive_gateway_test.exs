defmodule BPXETest.Engine.InclusiveGateway do
  use ExUnit.Case, async: true
  alias BPXE.Engine.Model
  alias BPXE.Engine.{Process, Event, Task, SequenceFlow}
  alias BPXE.Engine.Process.Log
  doctest BPXE.Engine.InclusiveGateway

  @xsi "http://www.w3.org/2001/XMLSchema-instance"

  test "forking inclusive gateway should send token to all forks that have truthful conditions" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, fork} = Process.add_inclusive_gateway(proc1, id: "fork")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, fork)

    {:ok, t1} = Process.add_task(proc1, id: "t1")
    {:ok, t2} = Process.add_task(proc1, id: "t2")

    {:ok, f1} = Process.establish_sequence_flow(proc1, "fork_1", fork, t1)
    {:ok, f2} = Process.establish_sequence_flow(proc1, "fork_2", fork, t2)

    SequenceFlow.add_condition_expression(
      f1,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`true`"
    )

    SequenceFlow.add_condition_expression(
      f2,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.InclusiveGatewayReceived{id: "fork", from: "s1"}})
    assert_receive({Log, %Log.TaskActivated{id: "t1"}})
    refute_receive({Log, %Log.TaskActivated{id: "t2"}})
  end

  test "joining inclusive gateway should send a combined tokend forward, only from forks that had truthful conditions" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, fork} = Process.add_inclusive_gateway(proc1, id: "fork")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, fork)

    {:ok, t1} = Process.add_script_task(proc1, id: "t1")
    {:ok, t2} = Process.add_script_task(proc1, id: "t2")
    {:ok, t3} = Process.add_script_task(proc1, id: "t3")

    {:ok, _} = Task.add_script(t1, ~s|
      flow.t1 = true
      |)

    {:ok, _} = Task.add_script(t2, ~s|
      flow.t2 = true
      |)

    {:ok, _} = Process.establish_sequence_flow(proc1, "fork_1", fork, t1)
    {:ok, _} = Process.establish_sequence_flow(proc1, "fork_2", fork, t2)
    {:ok, f3} = Process.establish_sequence_flow(proc1, "fork_3", fork, t3)

    SequenceFlow.add_condition_expression(
      f3,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    {:ok, join} = Process.add_inclusive_gateway(proc1, id: "join")

    {:ok, _} = Process.establish_sequence_flow(proc1, "join_1", t1, join)
    {:ok, _} = Process.establish_sequence_flow(proc1, "join_2", t2, join)
    {:ok, _} = Process.establish_sequence_flow(proc1, "join_3", t3, join)

    {:ok, t4} = Process.add_task(proc1, id: "t4")
    {:ok, _} = Process.establish_sequence_flow(proc1, "s4", join, t4)

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    # We should receive a collection of two tokens (third condition was falsy)
    assert_receive(
      {Log,
       %Log.FlowNodeActivated{
         id: "t4",
         token: %BPXE.Token{payload: %{"t1" => true, "t2" => true}}
       }}
    )
  end

  test "re-synthesizing inclusive gateway should not fail" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, fork} = Process.add_inclusive_gateway(proc1, id: "fork")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, fork)

    {:ok, t1} = Process.add_task(proc1, id: "t1")
    {:ok, t2} = Process.add_task(proc1, id: "t2")
    {:ok, t3} = Process.add_task(proc1, id: "t3")

    {:ok, _} = Process.establish_sequence_flow(proc1, "fork_1", fork, t1)
    {:ok, _} = Process.establish_sequence_flow(proc1, "fork_2", fork, t2)
    {:ok, f3} = Process.establish_sequence_flow(proc1, "fork_3", fork, t3)

    SequenceFlow.add_condition_expression(
      f3,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    {:ok, join} = Process.add_inclusive_gateway(proc1, id: "join")

    {:ok, _} = Process.establish_sequence_flow(proc1, "join_1", t1, join)
    {:ok, _} = Process.establish_sequence_flow(proc1, "join_2", t2, join)
    {:ok, _} = Process.establish_sequence_flow(proc1, "join_3", t3, join)

    {:ok, t4} = Process.add_task(proc1, id: "t4")
    {:ok, _} = Process.establish_sequence_flow(proc1, "s4", join, t4)

    {:ok, proc1} = Model.provision_process(pid, "proc1")

    assert :ok = Process.synthesize(proc1)
    assert :ok = Process.synthesize(proc1)
  end

  test "joining inclusive gateway should send a combined tokend forward, only from forks that had truthful conditions, only if they actually reached the gateway" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, fork} = Process.add_inclusive_gateway(proc1, id: "fork")

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, fork)

    {:ok, t1} = Process.add_task(proc1, id: "t1")
    {:ok, t2} = Process.add_intermediate_catch_event(proc1, id: "t2")
    {:ok, t3} = Process.add_task(proc1, id: "t3")

    # We are NOT going to use this signal
    {:ok, _} = Event.add_signal_event_definition(t2, signalRef: "signal1")

    {:ok, _} = Process.establish_sequence_flow(proc1, "fork_1", fork, t1)
    {:ok, _} = Process.establish_sequence_flow(proc1, "fork_2", fork, t2)
    {:ok, f3} = Process.establish_sequence_flow(proc1, "fork_3", fork, t3)

    SequenceFlow.add_condition_expression(
      f3,
      %{{@xsi, "type"} => "tFormalExpression"},
      "`false`"
    )

    {:ok, join} = Process.add_inclusive_gateway(proc1, id: "join")

    {:ok, _} = Process.establish_sequence_flow(proc1, "join_1", t1, join)
    {:ok, _} = Process.establish_sequence_flow(proc1, "join_2", t2, join)
    {:ok, _} = Process.establish_sequence_flow(proc1, "join_3", t3, join)

    {:ok, t4} = Process.add_task(proc1, id: "t4")
    {:ok, _} = Process.establish_sequence_flow(proc1, "s4", join, t4)

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    # The join should not proceed
    refute_receive({Log, %Log.FlowNodeActivated{id: "t4"}})
  end
end
