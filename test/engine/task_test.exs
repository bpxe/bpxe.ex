defmodule BPXETest.Engine.Task do
  use ExUnit.Case, async: true
  alias BPXE.Engine.Model
  alias BPXE.Engine.{Process, Task, Base, InputOutput, DataInputAssociation}
  alias BPXE.Engine.Process.Log
  doctest Task

  test "executes a script, captures state and retrieves it in other scripts" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, task} = Process.add_script_task(proc1, id: "task")
    {:ok, _} = Task.add_script(task, ~s|
      process.a = {}
      process.a.v = 1
      |)

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, task)

    {:ok, task2} = Process.add_script_task(proc1, id: "task2")
    {:ok, _} = Task.add_script(task2, ~s|
      process.a.v = process.a.v + 2
      |)

    {:ok, _} = Process.establish_sequence_flow(proc1, "s2", task, task2)

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    initial_vars = Base.variables(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.TaskCompleted{id: "task"}})
    assert_receive({Log, %Log.TaskCompleted{id: "task2"}})
    assert Base.variables(proc1) == Map.merge(initial_vars, %{"a" => %{"v" => 3}})
  end

  test "executes a script that modifies no state" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, task} = Process.add_script_task(proc1, id: "task")
    {:ok, _} = Task.add_script(task, ~s|
      |)

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, task)

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    initial_vars = Base.variables(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.TaskCompleted{id: "task"}})
    assert Base.variables(proc1) == initial_vars
  end

  test "executes a script that modifies token's payload" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, the_end} = Process.add_end_event(proc1, id: "end")
    {:ok, task} = Process.add_script_task(proc1, id: "task")
    {:ok, _} = Task.add_script(task, ~s|
      flow.a = 1
      |)

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, task)
    {:ok, _} = Process.establish_sequence_flow(proc1, "s2", task, the_end)

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.TaskCompleted{id: "task"}})

    assert_receive(
      {Log, %Log.FlowNodeActivated{id: "end", token: %BPXE.Token{payload: %{"a" => 1.0}}}}
    )
  end

  describe "serviceTask" do
    defmodule Service do
      use BPXE.Service, state: [called: false]

      def handle_request(%BPXE.Service.Request{payload: payload} = req, _model, _from, state) do
        if timeout = state.options[:timeout] do
          :timer.sleep(timeout)
        end

        {:reply, %BPXE.Service.Response{payload: payload}, %{state | called: req}}
      end

      def handle_call(:state, _from, state) do
        {:reply, state, state}
      end
    end

    test "invokes registered services with data inputs and captures data outputs" do
      {:ok, pid} = Model.start_link()
      {:ok, service} = BPXE.Service.start_link(Service)
      Model.register_service(pid, "service", service)

      {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

      {:ok, start} = Process.add_start_event(proc1, id: "start")
      {:ok, the_end} = Process.add_end_event(proc1, id: "end")

      {:ok, _} = Process.add_data_object(proc1, id: "do1")
      {:ok, _} = Process.add_data_object(proc1, id: "do2")

      {:ok, task} =
        Process.add_service_task(proc1, %{
          "id" => "task",
          {BPXE.BPMN.ext_spec(), "name"} => "service"
        })

      {:ok, io} = InputOutput.add_io_specification(task)

      {:ok, _} = InputOutput.add_data_input(io, id: "i1")
      {:ok, _} = InputOutput.add_data_input(io, id: "i2")

      {:ok, is} = InputOutput.add_input_set(io)
      {:ok, _} = InputOutput.add_data_input_ref(is, "i1")
      {:ok, _} = InputOutput.add_data_input_ref(is, "i2")

      {:ok, _} = DataInputAssociation.add(task, source: "do1", target: "i1")
      {:ok, _} = DataInputAssociation.add(task, source: "do2", target: "i2")

      {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, task)
      {:ok, _} = Process.establish_sequence_flow(proc1, "s2", task, the_end)

      {:ok, proc1} = Model.provision_process(pid, "proc1")
      :ok = Process.subscribe_log(proc1)

      {:ok, do1} = Process.data_object(proc1, "do1")
      Process.update_data_object(proc1, %{do1 | value: %{"hello" => "world"}})

      {:ok, do2} = Process.data_object(proc1, "do2")
      Process.update_data_object(proc1, %{do2 | value: %{"world" => "goodbye"}})

      assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
               Model.start(pid) |> List.keysort(0)

      assert_receive({Log, %Log.TaskCompleted{id: "task"}})

      state = GenServer.call(service, :state)

      assert %BPXE.Service.Request{payload: [%{"hello" => "world"}, %{"world" => "goodbye"}]} =
               state.called

      assert_receive({Log, %Log.FlowNodeActivated{id: "end"}})
    end

    test "should log an error if the service timed out" do
      {:ok, pid} = Model.start_link()
      {:ok, service} = BPXE.Service.start_link(Service, timeout: 100)
      Model.register_service(pid, "service", service)

      {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

      {:ok, start} = Process.add_start_event(proc1, id: "start")
      {:ok, the_end} = Process.add_end_event(proc1, id: "end")

      {:ok, task} =
        Process.add_service_task(proc1, %{
          "id" => "task",
          {BPXE.BPMN.ext_spec(), "name"} => "service",
          {BPXE.BPMN.ext_spec(), "timeout"} => "PT0.1S"
        })

      {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, task)
      {:ok, _} = Process.establish_sequence_flow(proc1, "s2", task, the_end)

      {:ok, proc1} = Model.provision_process(pid, "proc1")
      :ok = Process.subscribe_log(proc1)

      assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
               Model.start(pid) |> List.keysort(0)

      assert_receive(
        {Log,
         %Log.ServiceTimeoutOccurred{
           id: "task",
           timeout: 100
         }}
      )
    end
  end

  test "should log an error in script if it happens" do
    {:ok, pid} = Model.start_link()
    {:ok, proc1} = Model.add_process(pid, id: "proc1", name: "Proc 1")

    {:ok, start} = Process.add_start_event(proc1, id: "start")
    {:ok, the_end} = Process.add_end_event(proc1, id: "end")
    {:ok, task} = Process.add_script_task(proc1, id: "task")
    {:ok, _} = Task.add_script(task, ~s|
      this is not a script
      |)

    {:ok, _} = Process.establish_sequence_flow(proc1, "s1", start, task)
    {:ok, _} = Process.establish_sequence_flow(proc1, "s2", task, the_end)

    {:ok, proc1} = Model.provision_process(pid, "proc1")
    :ok = Process.subscribe_log(proc1)

    assert [{"proc1", [{"start", :ok}]}] |> List.keysort(0) ==
             Model.start(pid) |> List.keysort(0)

    assert_receive({Log, %Log.ScriptTaskErrorOccurred{id: "task"}})
    refute_receive({Log, %Log.FlowNodeForward{id: "task"}})
  end
end
