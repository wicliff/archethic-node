defmodule UnirisCore.P2P.Message.AcknowledgeStorage do
  @enforce_keys [:address]
  defstruct [:address]

  alias UnirisCore.Crypto

  @type t :: %__MODULE__{
          address: Crypto.versioned_hash()
        }
end