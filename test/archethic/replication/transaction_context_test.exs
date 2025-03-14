defmodule Archethic.Replication.TransactionContextTest do
  use ArchethicCase

  alias Archethic.Account.MemTables.UCOLedger

  alias Archethic.Crypto

  alias Archethic.P2P
  alias Archethic.P2P.Message.GetTransactionChainLength
  alias Archethic.P2P.Message.TransactionChainLength
  alias Archethic.P2P.Message.GetTransaction
  alias Archethic.P2P.Message.GetTransactionChain
  alias Archethic.P2P.Message.GetTransactionInputs
  alias Archethic.P2P.Message.TransactionInputList
  alias Archethic.P2P.Message.TransactionList
  alias Archethic.P2P.Node

  alias Archethic.Replication.TransactionContext

  alias Archethic.TransactionChain.Transaction
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Archethic.TransactionChain.TransactionInput
  alias Archethic.P2P.Message.GetFirstAddress
  alias Archethic.P2P.Message.NotFound
  # alias Archethic.P2P.Message.FirstAddress
  import Mox

  test "fetch_transaction/1 should retrieve the transaction" do
    MockClient
    |> stub(:send_message, fn _, %GetTransaction{}, _ ->
      {:ok, %Transaction{}}
    end)

    P2P.add_and_connect_node(%Node{
      ip: {127, 0, 0, 1},
      port: 3000,
      first_public_key: Crypto.last_node_public_key(),
      last_public_key: Crypto.last_node_public_key(),
      available?: true,
      geo_patch: "AAA",
      network_patch: "AAA",
      authorized?: true,
      authorization_date: DateTime.utc_now()
    })

    assert %Transaction{} = TransactionContext.fetch_transaction("@Alice1")
  end

  test "stream_transaction_chain/1 should retrieve the previous transaction chain" do
    MockClient
    |> stub(:send_message, fn
      _, %GetTransactionChain{}, _ ->
        {:ok, %TransactionList{transactions: [%Transaction{}]}}

      _, %GetTransactionChainLength{}, _ ->
        %TransactionChainLength{length: 1}

      _, %GetFirstAddress{}, _ ->
        {:ok, %NotFound{}}
    end)

    P2P.add_and_connect_node(%Node{
      ip: {127, 0, 0, 1},
      port: 3000,
      first_public_key: Crypto.last_node_public_key(),
      last_public_key: Crypto.last_node_public_key(),
      available?: true,
      geo_patch: "AAA",
      network_patch: "AAA",
      authorized?: true,
      authorization_date: DateTime.utc_now()
    })

    assert 1 =
             TransactionContext.stream_transaction_chain("@Alice1")
             |> Enum.count()
  end

  test "fetch_transaction_inputs/2 should retrieve the inputs of a transaction at a given date" do
    UCOLedger.add_unspent_output(
      "@Alice1",
      %UnspentOutput{
        from: "@Bob3",
        amount: 19_300_000,
        type: :UCO,
        timestamp: DateTime.utc_now() |> DateTime.truncate(:millisecond)
      }
    )

    MockClient
    |> stub(:send_message, fn _, %GetTransactionInputs{}, _ ->
      {:ok,
       %TransactionInputList{
         inputs: [
           %TransactionInput{
             from: "@Bob3",
             amount: 19_300_000,
             type: :UCO,
             timestamp: DateTime.utc_now()
           }
         ]
       }}
    end)

    P2P.add_and_connect_node(%Node{
      ip: {127, 0, 0, 1},
      port: 3000,
      first_public_key: Crypto.last_node_public_key(),
      last_public_key: Crypto.last_node_public_key(),
      available?: true,
      geo_patch: "AAA",
      network_patch: "AAA",
      authorized?: true,
      authorization_date: DateTime.utc_now()
    })

    assert [%TransactionInput{from: "@Bob3", amount: 19_300_000, type: :UCO}] =
             TransactionContext.fetch_transaction_inputs("@Alice1", DateTime.utc_now())
  end
end
