defmodule Archethic.ReplicationTest do
  use ArchethicCase, async: false

  alias Archethic.Crypto

  alias Archethic.Election

  alias Archethic.Mining.Fee

  alias Archethic.P2P
  alias Archethic.P2P.Message.GetTransactionChainLength
  alias Archethic.P2P.Message.TransactionChainLength
  alias Archethic.P2P.Message.GetTransaction
  alias Archethic.P2P.Message.GetTransactionChain
  alias Archethic.P2P.Message.GetTransactionInputs
  alias Archethic.P2P.Message.NotifyLastTransactionAddress
  alias Archethic.P2P.Message.NotFound
  alias Archethic.P2P.Message.Ok
  alias Archethic.P2P.Message.TransactionInputList
  alias Archethic.P2P.Message.TransactionList
  alias Archethic.P2P.Node
  alias Archethic.P2P.Message.GetFirstAddress
  # alias Archethic.P2P.Message.FirstAddress

  alias Archethic.Replication

  alias Archethic.SharedSecrets
  alias Archethic.SharedSecrets.MemTables.NetworkLookup

  alias Archethic.TransactionChain
  alias Archethic.TransactionChain.Transaction
  alias Archethic.TransactionChain.Transaction.CrossValidationStamp
  alias Archethic.TransactionChain.Transaction.ValidationStamp
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Archethic.TransactionChain.TransactionData
  alias Archethic.TransactionChain.TransactionInput

  doctest Archethic.Replication

  import Mox

  setup do
    Crypto.generate_deterministic_keypair("daily_nonce_seed")
    |> elem(0)
    |> NetworkLookup.set_daily_nonce_public_key(DateTime.utc_now() |> DateTime.add(-10))

    :ok
  end

  test "validate_and_store_transaction_chain/2" do
    P2P.add_and_connect_node(%Node{
      ip: {127, 0, 0, 1},
      port: 3000,
      authorized?: true,
      last_public_key: Crypto.last_node_public_key(),
      first_public_key: Crypto.last_node_public_key(),
      available?: true,
      geo_patch: "AAA",
      network_patch: "AAA",
      enrollment_date: DateTime.utc_now(),
      authorization_date: DateTime.utc_now() |> DateTime.add(-10),
      reward_address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
    })

    me = self()

    unspent_outputs = [
      %UnspentOutput{
        from: "@Alice2",
        amount: 1_000_000_000,
        type: :UCO,
        timestamp: DateTime.utc_now() |> DateTime.truncate(:millisecond)
      }
    ]

    p2p_context()
    tx = create_valid_transaction(unspent_outputs)

    MockDB
    # |> stub(:write_transaction_chain, fn [^tx] ->
    #  send(me, :replicated)
    #  :ok
    # end)
    |> expect(:write_transaction, fn ^tx ->
      send(me, :replicated)
      :ok
    end)

    MockClient
    |> stub(:send_message, fn
      _, %GetTransactionInputs{}, _ ->
        {:ok,
         %TransactionInputList{
           inputs:
             Enum.map(unspent_outputs, fn utxo ->
               %TransactionInput{
                 from: utxo.from,
                 amount: utxo.amount,
                 type: utxo.type,
                 timestamp:
                   DateTime.utc_now() |> DateTime.add(-30) |> DateTime.truncate(:millisecond)
               }
             end)
         }}

      _, %GetTransactionChain{}, _ ->
        Process.sleep(10)
        {:ok, %TransactionList{transactions: []}}

      _, %GetTransaction{}, _ ->
        {:ok, %NotFound{}}

      _, %GetTransactionChainLength{}, _ ->
        %TransactionChainLength{length: 1}

      _, %GetFirstAddress{}, _ ->
        {:ok, %NotFound{}}
    end)

    assert :ok = Replication.validate_and_store_transaction_chain(tx)

    Process.sleep(200)

    assert_received :replicated
  end

  test "validate_and_store_transaction/1" do
    me = self()

    unspent_outputs = [
      %UnspentOutput{
        from: "@Alice2",
        amount: 1_000_000_000,
        type: :UCO,
        timestamp: DateTime.utc_now() |> DateTime.truncate(:millisecond)
      }
    ]

    p2p_context()
    tx = create_valid_transaction(unspent_outputs)

    MockDB
    |> expect(:write_transaction, fn _ ->
      send(me, :replicated)
      :ok
    end)

    assert :ok = Replication.validate_and_store_transaction(tx)

    Process.sleep(200)

    assert_received :replicated
  end

  defp p2p_context do
    SharedSecrets.add_origin_public_key(:software, Crypto.first_node_public_key())

    welcome_node = %Node{
      first_public_key: "key1",
      last_public_key: "key1",
      available?: true,
      geo_patch: "BBB",
      network_patch: "BBB",
      enrollment_date: DateTime.utc_now(),
      reward_address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
    }

    coordinator_node = %Node{
      first_public_key: Crypto.first_node_public_key(),
      last_public_key: Crypto.last_node_public_key(),
      authorized?: true,
      available?: true,
      authorization_date: DateTime.add(DateTime.utc_now(), -1),
      geo_patch: "AAA",
      network_patch: "AAA",
      enrollment_date: DateTime.add(DateTime.utc_now(), -1),
      reward_address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
    }

    storage_nodes = [
      %Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key3",
        last_public_key: "key3",
        available?: true,
        geo_patch: "BBB",
        network_patch: "BBB",
        authorization_date: DateTime.add(DateTime.utc_now(), -1),
        reward_address: <<0::8, :crypto.strong_rand_bytes(32)::binary>>
      }
    ]

    Enum.each(storage_nodes, &P2P.add_and_connect_node(&1))

    P2P.add_and_connect_node(welcome_node)
    P2P.add_and_connect_node(coordinator_node)

    %{
      welcome_node: welcome_node,
      coordinator_node: coordinator_node,
      storage_nodes: storage_nodes
    }
  end

  defp create_valid_transaction(unspent_outputs) do
    tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)
    timestamp = DateTime.utc_now() |> DateTime.truncate(:millisecond)

    ledger_operations =
      %LedgerOperations{
        fee: Fee.calculate(tx, 0.07)
      }
      |> LedgerOperations.consume_inputs(tx.address, unspent_outputs, timestamp)

    validation_stamp =
      %ValidationStamp{
        timestamp: timestamp,
        proof_of_work: Crypto.origin_node_public_key(),
        proof_of_election:
          Election.validation_nodes_election_seed_sorting(tx, DateTime.utc_now()),
        proof_of_integrity: TransactionChain.proof_of_integrity([tx]),
        ledger_operations: ledger_operations,
        protocol_version: ArchethicCase.current_protocol_version()
      }
      |> ValidationStamp.sign()

    cross_validation_stamp = CrossValidationStamp.sign(%CrossValidationStamp{}, validation_stamp)

    %{tx | validation_stamp: validation_stamp, cross_validation_stamps: [cross_validation_stamp]}
  end

  describe "acknowledge_previous_storage_nodes/2" do
    test "should register new address on chain" do
      MockDB
      |> stub(:add_last_transaction_address, fn _address, _last_address, _ ->
        :ok
      end)
      |> expect(:get_last_chain_address, fn _ -> {"@Alice2", DateTime.utc_now()} end)

      assert :ok =
               Replication.acknowledge_previous_storage_nodes(
                 "@Alice2",
                 "@Alice1",
                 DateTime.utc_now()
               )

      assert {"@Alice2", _} = TransactionChain.get_last_address("@Alice1")
    end

    test "should notify previous storage pool if transaction exists" do
      MockDB
      |> stub(:add_last_transaction_address, fn _address, _last_address, _ ->
        :ok
      end)
      |> expect(:get_last_chain_address, fn _ -> {"@Alice2", DateTime.utc_now()} end)
      |> stub(:get_transaction, fn _, _ ->
        {:ok, %Transaction{previous_public_key: "Alice1"}}
      end)

      me = self()

      MockClient
      |> stub(:send_message, fn _, %NotifyLastTransactionAddress{address: _}, _ ->
        send(me, :notification_sent)
        {:ok, %Ok{}}
      end)

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: :crypto.strong_rand_bytes(32),
        last_public_key: :crypto.strong_rand_bytes(32),
        geo_patch: "AAA",
        available?: true,
        authorization_date: DateTime.utc_now(),
        authorized?: true,
        reward_address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      })

      assert :ok =
               Replication.acknowledge_previous_storage_nodes(
                 "@Alice2",
                 "@Alice1",
                 DateTime.utc_now()
               )

      assert {"@Alice2", _} = TransactionChain.get_last_address("@Alice1")

      assert_receive :notification_sent, 500
    end
  end
end
