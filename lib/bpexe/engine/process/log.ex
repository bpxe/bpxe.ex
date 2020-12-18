defmodule BPEXE.Engine.Process.Log do
  defmodule FlowNodeActivated do
    defstruct pid: nil, id: nil, message_id: nil, message: nil
  end

  defmodule FlowNodeForward do
    defstruct pid: nil, id: nil, message_id: nil, to: []
  end

  defmodule ExclusiveGatewayActivated do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule EventBasedGatewayActivated do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule EventBasedGatewayCompleted do
    defstruct pid: nil, id: nil, message_id: nil, to: []
  end

  defmodule ParallelGatewayReceived do
    defstruct pid: nil, id: nil, message_id: nil, from: nil
  end

  defmodule ParallelGatewayCompleted do
    defstruct pid: nil, id: nil, message_id: nil, to: []
  end

  defmodule PrecedenceGatewayActivated do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule PrecedenceGatewayPrecedenceEstablished do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule PrecedenceGatewayMessageDiscarded do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule EventActivated do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule EventTrigerred do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule EventCompleted do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule SequenceFlowStarted do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule SequenceFlowCompleted do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule TaskActivated do
    defstruct pid: nil, id: nil, message_id: nil
  end

  defmodule TaskCompleted do
    defstruct pid: nil, id: nil, message_id: nil
  end
end
