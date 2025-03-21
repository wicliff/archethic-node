defmodule Archethic.P2P.Message.UnspentOutputList do
  @moduledoc """
  Represents a message with a list of unspent outputs
  """
  defstruct unspent_outputs: [], more?: false, offset: 0

  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  @type t :: %__MODULE__{
          unspent_outputs: list(UnspentOutput.t()),
          more?: boolean(),
          offset: non_neg_integer()
        }
end
