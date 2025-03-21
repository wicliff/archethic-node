defmodule Archethic.P2P.MessageTest do
  use ArchethicCase

  alias Archethic.Crypto

  alias Archethic.P2P.Message
  alias Archethic.P2P.Message.AcknowledgeStorage
  alias Archethic.P2P.Message.AddMiningContext
  alias Archethic.P2P.Message.Balance
  alias Archethic.P2P.Message.BootstrappingNodes
  alias Archethic.P2P.Message.CrossValidate
  alias Archethic.P2P.Message.CrossValidationDone
  alias Archethic.P2P.Message.EncryptedStorageNonce
  alias Archethic.P2P.Message.Error
  alias Archethic.P2P.Message.FirstPublicKey
  alias Archethic.P2P.Message.GetBalance
  alias Archethic.P2P.Message.GetBootstrappingNodes
  alias Archethic.P2P.Message.GetFirstPublicKey
  alias Archethic.P2P.Message.GetLastTransaction
  alias Archethic.P2P.Message.GetLastTransactionAddress
  alias Archethic.P2P.Message.GetP2PView
  alias Archethic.P2P.Message.GetStorageNonce
  alias Archethic.P2P.Message.GetTransaction
  alias Archethic.P2P.Message.GetTransactionChain
  alias Archethic.P2P.Message.GetTransactionChainLength
  alias Archethic.P2P.Message.GetTransactionInputs
  alias Archethic.P2P.Message.GetTransactionSummary
  alias Archethic.P2P.Message.GetUnspentOutputs
  alias Archethic.P2P.Message.LastTransactionAddress
  alias Archethic.P2P.Message.ListNodes
  alias Archethic.P2P.Message.NewTransaction
  alias Archethic.P2P.Message.NodeAvailability
  alias Archethic.P2P.Message.NodeList
  alias Archethic.P2P.Message.NotFound
  alias Archethic.P2P.Message.NotifyEndOfNodeSync
  alias Archethic.P2P.Message.NotifyLastTransactionAddress
  alias Archethic.P2P.Message.Ok
  alias Archethic.P2P.Message.P2PView
  alias Archethic.P2P.Message.Ping
  alias Archethic.P2P.Message.RegisterBeaconUpdates
  alias Archethic.P2P.Message.ReplicateTransaction
  alias Archethic.P2P.Message.ReplicateTransactionChain
  alias Archethic.P2P.Message.StartMining
  alias Archethic.P2P.Message.StartMining
  alias Archethic.P2P.Message.TransactionChainLength
  alias Archethic.P2P.Message.TransactionInputList
  alias Archethic.P2P.Message.TransactionList
  alias Archethic.P2P.Message.UnspentOutputList
  alias Archethic.P2P.Node

  alias Archethic.TransactionChain.Transaction
  alias Archethic.TransactionChain.Transaction.CrossValidationStamp
  alias Archethic.TransactionChain.Transaction.ValidationStamp
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput
  alias Archethic.TransactionChain.TransactionData
  alias Archethic.TransactionChain.TransactionInput

  doctest Message

  describe "symmetric encoding/decoding of" do
    test "GetBootstrappingNodes message" do
      assert %GetBootstrappingNodes{patch: "AAA"} ==
               %GetBootstrappingNodes{patch: "AAA"}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetStorageNonce message" do
      {public_key, _} = Crypto.generate_deterministic_keypair("seed", :secp256r1)

      assert %GetStorageNonce{public_key: public_key} ==
               %GetStorageNonce{public_key: public_key}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "ListNodes message" do
      assert %ListNodes{} =
               %ListNodes{}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetTransaction message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      assert %GetTransaction{address: address} ==
               %GetTransaction{address: address}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetTransactionChain message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      assert %GetTransactionChain{address: address} ==
               %GetTransactionChain{address: address}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetUnspentOutputs message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      assert %GetUnspentOutputs{address: address} ==
               %GetUnspentOutputs{address: address}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "NewTransaction message" do
      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)

      assert %NewTransaction{transaction: tx} ==
               %NewTransaction{transaction: tx}
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "StartMining message" do
      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)
      {welcome_node_public_key, _} = Crypto.generate_deterministic_keypair("wkey")

      validation_node_public_keys =
        Enum.map(1..10, fn i ->
          {pub, _} = Crypto.generate_deterministic_keypair("vkey" <> Integer.to_string(i))
          pub
        end)

      assert %StartMining{
               transaction: tx,
               welcome_node_public_key: welcome_node_public_key,
               validation_node_public_keys: validation_node_public_keys
             } ==
               %StartMining{
                 transaction: tx,
                 welcome_node_public_key: welcome_node_public_key,
                 validation_node_public_keys: validation_node_public_keys
               }
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "AddMiningContext message" do
      msg = %AddMiningContext{
        address:
          <<0, 0, 227, 129, 244, 35, 48, 113, 14, 75, 1, 127, 107, 32, 29, 93, 232, 119, 254, 1,
            65, 32, 47, 129, 164, 142, 240, 43, 22, 81, 188, 212, 56, 238>>,
        validation_node_public_key:
          <<0, 0, 92, 208, 222, 119, 27, 128, 82, 69, 163, 128, 196, 105, 19, 18, 99, 217, 105,
            80, 238, 155, 239, 91, 54, 82, 200, 16, 121, 32, 83, 63, 79, 88>>,
        previous_storage_nodes_public_keys: [
          <<0, 0, 22, 38, 34, 13, 213, 91, 210, 214, 66, 148, 122, 220, 63, 176, 232, 205, 35,
            153, 176, 223, 178, 72, 88, 6, 41, 167, 163, 205, 98, 172, 249, 141>>
        ],
        chain_storage_nodes_view: <<1::1, 0::1, 0::1, 1::1, 0::1>>,
        beacon_storage_nodes_view: <<0::1, 1::1, 1::1, 1::1>>,
        io_storage_nodes_view: <<0::1, 1::1, 1::1, 1::1>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "CrossValidate message" do
      msg = %CrossValidate{
        address:
          <<0, 0, 227, 129, 244, 35, 48, 113, 14, 75, 1, 127, 107, 32, 29, 93, 232, 119, 254, 1,
            65, 32, 47, 129, 164, 142, 240, 43, 22, 81, 188, 212, 56, 238>>,
        validation_stamp: %ValidationStamp{
          timestamp: ~U[2020-06-26 06:37:04.000Z],
          proof_of_work:
            <<0, 0, 206, 159, 122, 114, 106, 65, 116, 18, 224, 214, 2, 26, 213, 36, 82, 175, 176,
              180, 191, 255, 46, 113, 134, 227, 253, 189, 81, 16, 97, 33, 114, 85>>,
          proof_of_integrity:
            <<0, 63, 70, 80, 109, 148, 124, 179, 105, 198, 92, 39, 212, 240, 48, 96, 69, 244, 213,
              246, 75, 82, 83, 170, 121, 42, 105, 30, 23, 3, 231, 178, 153>>,
          proof_of_election:
            <<74, 224, 26, 42, 253, 85, 104, 246, 72, 244, 189, 182, 165, 94, 92, 20, 166, 149,
              124, 246, 219, 170, 160, 168, 206, 214, 236, 215, 211, 121, 95, 149, 132, 136, 114,
              244, 132, 44, 255, 222, 98, 76, 247, 125, 45, 170, 95, 51, 46, 229, 21, 32, 226, 99,
              16, 5, 107, 207, 32, 240, 23, 85, 219, 247>>,
          ledger_operations: %LedgerOperations{
            fee: 1_000_000,
            transaction_movements: [],
            unspent_outputs: []
          },
          signature:
            <<231, 4, 252, 234, 6, 126, 91, 87, 41, 70, 76, 220, 116, 238, 128, 189, 94, 124, 207,
              90, 32, 143, 239, 153, 101, 148, 189, 125, 25, 235, 20, 207, 168, 10, 86, 59, 14,
              249, 104, 144, 141, 151, 232, 149, 24, 189, 225, 56, 65, 208, 220, 202, 169, 166,
              36, 248, 98, 108, 241, 114, 47, 102, 176, 212>>,
          protocol_version: ArchethicCase.current_protocol_version()
        },
        replication_tree: %{
          chain: [<<1::1, 0::1, 1::1>>, <<0::1, 1::1, 0::1>>, <<1::1, 0::1, 0::1>>],
          beacon: [<<1::1, 0::1, 1::1>>, <<0::1, 1::1, 0::1>>, <<1::1, 0::1, 0::1>>],
          IO: [<<1::1, 0::1, 1::1>>, <<0::1, 1::1, 0::1>>, <<1::1, 0::1, 0::1>>]
        },
        confirmed_validation_nodes: <<1::1, 1::1>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "CrossValidationDone message" do
      msg = %CrossValidationDone{
        address:
          <<0, 0, 227, 129, 244, 35, 48, 113, 14, 75, 1, 127, 107, 32, 29, 93, 232, 119, 254, 1,
            65, 32, 47, 129, 164, 142, 240, 43, 22, 81, 188, 212, 56, 238>>,
        cross_validation_stamp: %CrossValidationStamp{
          node_public_key:
            <<0, 0, 92, 208, 222, 119, 27, 128, 82, 69, 163, 128, 196, 105, 19, 18, 99, 217, 105,
              80, 238, 155, 239, 91, 54, 82, 200, 16, 121, 32, 83, 63, 79, 88>>,
          signature:
            <<231, 4, 252, 234, 6, 126, 91, 87, 41, 70, 76, 220, 116, 238, 128, 189, 94, 124, 207,
              90, 32, 143, 239, 153, 101, 148, 189, 125, 25, 235, 20, 207, 168, 10, 86, 59, 14,
              249, 104, 144, 141, 151, 232, 149, 24, 189, 225, 56, 65, 208, 220, 202, 169, 166,
              36, 248, 98, 108, 241, 114, 47, 102, 176, 212>>,
          inconsistencies: []
        }
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "ReplicateTransactionChain message" do
      msg = %ReplicateTransactionChain{
        transaction: %Transaction{
          address:
            <<0, 0, 46, 140, 65, 49, 7, 111, 10, 130, 53, 72, 25, 43, 47, 81, 130, 161, 225, 87,
              144, 186, 117, 170, 105, 205, 173, 102, 49, 176, 8, 45, 49, 82>>,
          type: :transfer,
          data: %TransactionData{},
          previous_public_key:
            <<0, 0, 221, 122, 240, 119, 132, 26, 237, 200, 88, 209, 23, 240, 176, 190, 89, 67,
              120, 61, 106, 117, 10, 14, 12, 177, 171, 237, 66, 113, 45, 18, 195, 249>>,
          previous_signature:
            <<206, 119, 19, 59, 13, 255, 98, 28, 80, 65, 115, 97, 216, 28, 51, 237, 180, 94, 197,
              228, 50, 240, 155, 61, 242, 17, 172, 225, 223, 8, 104, 220, 195, 33, 46, 185, 88,
              223, 224, 105, 41, 107, 67, 6, 92, 78, 15, 142, 47, 192, 214, 66, 124, 30, 228, 167,
              96, 61, 68, 188, 152, 246, 42, 246>>,
          origin_signature:
            <<238, 102, 94, 142, 31, 243, 44, 162, 254, 161, 177, 121, 166, 204, 152, 126, 66,
              207, 0, 75, 174, 126, 64, 226, 155, 92, 71, 152, 119, 80, 150, 119, 88, 40, 110,
              175, 135, 180, 179, 28, 57, 84, 35, 156, 173, 212, 235, 155, 226, 41, 148, 171, 132,
              196, 120, 51, 136, 4, 78, 123, 70, 44, 76, 162>>,
          validation_stamp: %ValidationStamp{
            timestamp: ~U[2020-06-26 06:37:04.000Z],
            proof_of_work:
              <<0, 0, 206, 159, 122, 114, 106, 65, 116, 18, 224, 214, 2, 26, 213, 36, 82, 175,
                176, 180, 191, 255, 46, 113, 134, 227, 253, 189, 81, 16, 97, 33, 114, 85>>,
            proof_of_integrity:
              <<0, 63, 70, 80, 109, 148, 124, 179, 105, 198, 92, 39, 212, 240, 48, 96, 69, 244,
                213, 246, 75, 82, 83, 170, 121, 42, 105, 30, 23, 3, 231, 178, 153>>,
            proof_of_election:
              <<74, 224, 26, 42, 253, 85, 104, 246, 72, 244, 189, 182, 165, 94, 92, 20, 166, 149,
                124, 246, 219, 170, 160, 168, 206, 214, 236, 215, 211, 121, 95, 149, 132, 136,
                114, 244, 132, 44, 255, 222, 98, 76, 247, 125, 45, 170, 95, 51, 46, 229, 21, 32,
                226, 99, 16, 5, 107, 207, 32, 240, 23, 85, 219, 247>>,
            ledger_operations: %LedgerOperations{
              fee: 1_000_000,
              transaction_movements: [],
              unspent_outputs: []
            },
            signature:
              <<231, 4, 252, 234, 6, 126, 91, 87, 41, 70, 76, 220, 116, 238, 128, 189, 94, 124,
                207, 90, 32, 143, 239, 153, 101, 148, 189, 125, 25, 235, 20, 207, 168, 10, 86, 59,
                14, 249, 104, 144, 141, 151, 232, 149, 24, 189, 225, 56, 65, 208, 220, 202, 169,
                166, 36, 248, 98, 108, 241, 114, 47, 102, 176, 212>>,
            protocol_version: ArchethicCase.current_protocol_version()
          },
          cross_validation_stamps: [
            %CrossValidationStamp{
              node_public_key:
                <<0, 0, 161, 146, 84, 231, 250, 25, 216, 247, 158, 26, 32, 219, 6, 128, 253, 127,
                  119, 121, 206, 58, 142, 140, 194, 61, 235, 224, 193, 56, 82, 253, 19, 131>>,
              signature:
                <<44, 66, 52, 214, 59, 145, 63, 7, 237, 115, 10, 255, 237, 85, 175, 115, 177, 85,
                  20, 76, 108, 118, 141, 190, 6, 84, 28, 134, 37, 235, 114, 30, 169, 151, 124,
                  242, 58, 26, 146, 125, 89, 64, 181, 253, 58, 199, 73, 12, 237, 134, 93, 73, 157,
                  123, 248, 199, 252, 138, 202, 227, 69, 83, 11, 29>>,
              inconsistencies: []
            }
          ]
        }
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "ReplicateTransaction message" do
      msg = %ReplicateTransaction{
        transaction: %Transaction{
          address:
            <<0, 0, 46, 140, 65, 49, 7, 111, 10, 130, 53, 72, 25, 43, 47, 81, 130, 161, 225, 87,
              144, 186, 117, 170, 105, 205, 173, 102, 49, 176, 8, 45, 49, 82>>,
          type: :transfer,
          data: %TransactionData{},
          previous_public_key:
            <<0, 0, 221, 122, 240, 119, 132, 26, 237, 200, 88, 209, 23, 240, 176, 190, 89, 67,
              120, 61, 106, 117, 10, 14, 12, 177, 171, 237, 66, 113, 45, 18, 195, 249>>,
          previous_signature:
            <<206, 119, 19, 59, 13, 255, 98, 28, 80, 65, 115, 97, 216, 28, 51, 237, 180, 94, 197,
              228, 50, 240, 155, 61, 242, 17, 172, 225, 223, 8, 104, 220, 195, 33, 46, 185, 88,
              223, 224, 105, 41, 107, 67, 6, 92, 78, 15, 142, 47, 192, 214, 66, 124, 30, 228, 167,
              96, 61, 68, 188, 152, 246, 42, 246>>,
          origin_signature:
            <<238, 102, 94, 142, 31, 243, 44, 162, 254, 161, 177, 121, 166, 204, 152, 126, 66,
              207, 0, 75, 174, 126, 64, 226, 155, 92, 71, 152, 119, 80, 150, 119, 88, 40, 110,
              175, 135, 180, 179, 28, 57, 84, 35, 156, 173, 212, 235, 155, 226, 41, 148, 171, 132,
              196, 120, 51, 136, 4, 78, 123, 70, 44, 76, 162>>,
          validation_stamp: %ValidationStamp{
            timestamp: ~U[2020-06-26 06:37:04.000Z],
            proof_of_work:
              <<0, 0, 206, 159, 122, 114, 106, 65, 116, 18, 224, 214, 2, 26, 213, 36, 82, 175,
                176, 180, 191, 255, 46, 113, 134, 227, 253, 189, 81, 16, 97, 33, 114, 85>>,
            proof_of_integrity:
              <<0, 63, 70, 80, 109, 148, 124, 179, 105, 198, 92, 39, 212, 240, 48, 96, 69, 244,
                213, 246, 75, 82, 83, 170, 121, 42, 105, 30, 23, 3, 231, 178, 153>>,
            proof_of_election:
              <<74, 224, 26, 42, 253, 85, 104, 246, 72, 244, 189, 182, 165, 94, 92, 20, 166, 149,
                124, 246, 219, 170, 160, 168, 206, 214, 236, 215, 211, 121, 95, 149, 132, 136,
                114, 244, 132, 44, 255, 222, 98, 76, 247, 125, 45, 170, 95, 51, 46, 229, 21, 32,
                226, 99, 16, 5, 107, 207, 32, 240, 23, 85, 219, 247>>,
            ledger_operations: %LedgerOperations{
              fee: 1_000_000,
              transaction_movements: [],
              unspent_outputs: []
            },
            signature:
              <<231, 4, 252, 234, 6, 126, 91, 87, 41, 70, 76, 220, 116, 238, 128, 189, 94, 124,
                207, 90, 32, 143, 239, 153, 101, 148, 189, 125, 25, 235, 20, 207, 168, 10, 86, 59,
                14, 249, 104, 144, 141, 151, 232, 149, 24, 189, 225, 56, 65, 208, 220, 202, 169,
                166, 36, 248, 98, 108, 241, 114, 47, 102, 176, 212>>,
            protocol_version: ArchethicCase.current_protocol_version()
          },
          cross_validation_stamps: [
            %CrossValidationStamp{
              node_public_key:
                <<0, 0, 161, 146, 84, 231, 250, 25, 216, 247, 158, 26, 32, 219, 6, 128, 253, 127,
                  119, 121, 206, 58, 142, 140, 194, 61, 235, 224, 193, 56, 82, 253, 19, 131>>,
              signature:
                <<44, 66, 52, 214, 59, 145, 63, 7, 237, 115, 10, 255, 237, 85, 175, 115, 177, 85,
                  20, 76, 108, 118, 141, 190, 6, 84, 28, 134, 37, 235, 114, 30, 169, 151, 124,
                  242, 58, 26, 146, 125, 89, 64, 181, 253, 58, 199, 73, 12, 237, 134, 93, 73, 157,
                  123, 248, 199, 252, 138, 202, 227, 69, 83, 11, 29>>,
              inconsistencies: []
            }
          ]
        }
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "AcknowledgeStorage message" do
      signature = :crypto.strong_rand_bytes(32)
      tx_address = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      node_public_key = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>

      assert %AcknowledgeStorage{
               signature: signature,
               address: tx_address,
               node_public_key: node_public_key
             } ==
               %AcknowledgeStorage{
                 signature: signature,
                 address: tx_address,
                 node_public_key: node_public_key
               }
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "NotifyEndOfNodeSync message" do
      msg = %NotifyEndOfNodeSync{
        node_public_key:
          <<0, 0, 38, 105, 235, 147, 234, 114, 41, 1, 152, 148, 120, 31, 200, 255, 174, 190, 91,
            100, 169, 225, 113, 249, 125, 21, 168, 14, 196, 222, 140, 87, 143, 241>>,
        timestamp: ~U[2020-06-25 15:11:53Z] |> DateTime.truncate(:second)
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetLastTransaction message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      assert %GetLastTransaction{
               address: address
             } ==
               %GetLastTransaction{
                 address: address
               }
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetBalance message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      assert %GetBalance{
               address: address
             } ==
               %GetBalance{
                 address: address
               }
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetTransactionInputs message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      assert %GetTransactionInputs{
               address: address
             } ==
               %GetTransactionInputs{
                 address: address
               }
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "Ok message" do
      assert %Ok{} == %Ok{} |> Message.encode() |> Message.decode() |> elem(0)
    end

    test "NotFound message" do
      assert %NotFound{} == %NotFound{} |> Message.encode() |> Message.decode() |> elem(0)
    end

    test "Transaction message" do
      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)

      assert tx ==
               tx
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "TransactionList message" do
      msg = %TransactionList{
        transactions: [
          %Transaction{
            address:
              <<0, 0, 46, 140, 65, 49, 7, 111, 10, 130, 53, 72, 25, 43, 47, 81, 130, 161, 225, 87,
                144, 186, 117, 170, 105, 205, 173, 102, 49, 176, 8, 45, 49, 82>>,
            type: :transfer,
            data: %TransactionData{},
            previous_public_key:
              <<0, 0, 221, 122, 240, 119, 132, 26, 237, 200, 88, 209, 23, 240, 176, 190, 89, 67,
                120, 61, 106, 117, 10, 14, 12, 177, 171, 237, 66, 113, 45, 18, 195, 249>>,
            previous_signature:
              <<206, 119, 19, 59, 13, 255, 98, 28, 80, 65, 115, 97, 216, 28, 51, 237, 180, 94,
                197, 228, 50, 240, 155, 61, 242, 17, 172, 225, 223, 8, 104, 220, 195, 33, 46, 185,
                88, 223, 224, 105, 41, 107, 67, 6, 92, 78, 15, 142, 47, 192, 214, 66, 124, 30,
                228, 167, 96, 61, 68, 188, 152, 246, 42, 246>>,
            origin_signature:
              <<238, 102, 94, 142, 31, 243, 44, 162, 254, 161, 177, 121, 166, 204, 152, 126, 66,
                207, 0, 75, 174, 126, 64, 226, 155, 92, 71, 152, 119, 80, 150, 119, 88, 40, 110,
                175, 135, 180, 179, 28, 57, 84, 35, 156, 173, 212, 235, 155, 226, 41, 148, 171,
                132, 196, 120, 51, 136, 4, 78, 123, 70, 44, 76, 162>>,
            validation_stamp: %ValidationStamp{
              timestamp: ~U[2020-06-26 06:37:04.000Z],
              proof_of_work:
                <<0, 0, 206, 159, 122, 114, 106, 65, 116, 18, 224, 214, 2, 26, 213, 36, 82, 175,
                  176, 180, 191, 255, 46, 113, 134, 227, 253, 189, 81, 16, 97, 33, 114, 85>>,
              proof_of_election:
                <<74, 224, 26, 42, 253, 85, 104, 246, 72, 244, 189, 182, 165, 94, 92, 20, 166,
                  149, 124, 246, 219, 170, 160, 168, 206, 214, 236, 215, 211, 121, 95, 149, 132,
                  136, 114, 244, 132, 44, 255, 222, 98, 76, 247, 125, 45, 170, 95, 51, 46, 229,
                  21, 32, 226, 99, 16, 5, 107, 207, 32, 240, 23, 85, 219, 247>>,
              proof_of_integrity:
                <<0, 63, 70, 80, 109, 148, 124, 179, 105, 198, 92, 39, 212, 240, 48, 96, 69, 244,
                  213, 246, 75, 82, 83, 170, 121, 42, 105, 30, 23, 3, 231, 178, 153>>,
              ledger_operations: %LedgerOperations{
                fee: 1_000_000,
                transaction_movements: [],
                unspent_outputs: []
              },
              signature:
                <<231, 4, 252, 234, 6, 126, 91, 87, 41, 70, 76, 220, 116, 238, 128, 189, 94, 124,
                  207, 90, 32, 143, 239, 153, 101, 148, 189, 125, 25, 235, 20, 207, 168, 10, 86,
                  59, 14, 249, 104, 144, 141, 151, 232, 149, 24, 189, 225, 56, 65, 208, 220, 202,
                  169, 166, 36, 248, 98, 108, 241, 114, 47, 102, 176, 212>>,
              protocol_version: ArchethicCase.current_protocol_version()
            },
            cross_validation_stamps: [
              %CrossValidationStamp{
                node_public_key:
                  <<0, 0, 161, 146, 84, 231, 250, 25, 216, 247, 158, 26, 32, 219, 6, 128, 253,
                    127, 119, 121, 206, 58, 142, 140, 194, 61, 235, 224, 193, 56, 82, 253, 19,
                    131>>,
                signature:
                  <<44, 66, 52, 214, 59, 145, 63, 7, 237, 115, 10, 255, 237, 85, 175, 115, 177,
                    85, 20, 76, 108, 118, 141, 190, 6, 84, 28, 134, 37, 235, 114, 30, 169, 151,
                    124, 242, 58, 26, 146, 125, 89, 64, 181, 253, 58, 199, 73, 12, 237, 134, 93,
                    73, 157, 123, 248, 199, 252, 138, 202, 227, 69, 83, 11, 29>>,
                inconsistencies: []
              }
            ]
          }
        ]
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "UnspentOutputList message " do
      msg = %UnspentOutputList{
        unspent_outputs: [
          %UnspentOutput{
            from:
              <<0, 0, 214, 107, 17, 107, 227, 11, 17, 43, 204, 48, 78, 129, 145, 126, 45, 68, 194,
                159, 19, 92, 240, 29, 37, 105, 183, 232, 56, 42, 163, 236, 251, 186>>,
            amount: 1_050_000_000,
            type: :UCO,
            timestamp: DateTime.utc_now() |> DateTime.truncate(:millisecond)
          }
        ]
      }

      assert msg
             |> Message.encode()
             |> Message.decode()
             |> elem(0)
    end

    test "NodeList message" do
      msg = %NodeList{
        nodes: [
          %Node{
            ip: {127, 0, 0, 1},
            port: 3000,
            http_port: 4000,
            first_public_key:
              <<0, 0, 182, 67, 168, 252, 227, 203, 142, 164, 142, 248, 159, 209, 249, 247, 86, 64,
                92, 224, 91, 182, 122, 49, 209, 169, 96, 111, 219, 204, 57, 250, 59, 226>>,
            last_public_key:
              <<0, 0, 182, 67, 168, 252, 227, 203, 142, 164, 142, 248, 159, 209, 249, 247, 86, 64,
                92, 224, 91, 182, 122, 49, 209, 169, 96, 111, 219, 204, 57, 250, 59, 226>>,
            geo_patch: "FA9",
            network_patch: "AVC",
            available?: true,
            average_availability: 0.8,
            enrollment_date: ~U[2020-06-26 08:36:11Z],
            authorization_date: ~U[2020-06-26 08:36:11Z],
            authorized?: true,
            last_address:
              <<0, 0, 165, 32, 187, 102, 112, 133, 38, 17, 232, 54, 228, 173, 254, 94, 179, 32,
                173, 88, 122, 234, 88, 139, 82, 26, 113, 42, 8, 183, 190, 163, 221, 112>>,
            reward_address:
              <<0, 0, 163, 237, 233, 93, 14, 241, 241, 8, 144, 218, 105, 16, 138, 243, 223, 17,
                182, 87, 9, 7, 53, 146, 174, 125, 5, 244, 42, 35, 209, 142, 24, 164>>,
            origin_public_key:
              <<0, 0, 76, 168, 99, 61, 84, 206, 158, 226, 212, 161, 60, 62, 55, 101, 249, 142,
                174, 178, 157, 241, 148, 35, 19, 177, 109, 40, 224, 179, 31, 66, 129, 4>>
          }
        ]
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "Balance message" do
      token_address = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      token_id = 0

      assert %Balance{
               uco: 1_050_000_000,
               token: %{
                 {token_address, token_id} => 1_000_000_000
               }
             } ==
               %Balance{
                 uco: 1_050_000_000,
                 token: %{
                   {token_address, token_id} => 1_000_000_000
                 }
               }
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "EncryptedStorageNonce message" do
      msg = %EncryptedStorageNonce{
        digest:
          <<113, 15, 188, 151, 173, 16, 195, 140, 160, 244, 75, 59, 47, 220, 113, 96, 241, 34, 99,
            157, 115, 207, 195, 78, 32, 175, 171, 213, 154, 54, 113, 236>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "BootstrappingNodes message" do
      msg = %BootstrappingNodes{
        new_seeds: [
          %Node{
            ip: {127, 0, 0, 1},
            port: 3000,
            http_port: 4000,
            first_public_key:
              <<0, 0, 182, 67, 168, 252, 227, 203, 142, 164, 142, 248, 159, 209, 249, 247, 86, 64,
                92, 224, 91, 182, 122, 49, 209, 169, 96, 111, 219, 204, 57, 250, 59, 226>>,
            last_public_key:
              <<0, 0, 182, 67, 168, 252, 227, 203, 142, 164, 142, 248, 159, 209, 249, 247, 86, 64,
                92, 224, 91, 182, 122, 49, 209, 169, 96, 111, 219, 204, 57, 250, 59, 226>>,
            geo_patch: "FA9",
            network_patch: "AVC",
            available?: true,
            average_availability: 0.8,
            enrollment_date: ~U[2020-06-26 08:36:11Z],
            authorization_date: ~U[2020-06-26 08:36:11Z],
            authorized?: true,
            reward_address:
              <<0, 0, 163, 237, 233, 93, 14, 241, 241, 8, 144, 218, 105, 16, 138, 243, 223, 17,
                182, 87, 9, 7, 53, 146, 174, 125, 5, 244, 42, 35, 209, 142, 24, 164>>,
            last_address:
              <<0, 0, 165, 32, 187, 102, 112, 133, 38, 17, 232, 54, 228, 173, 254, 94, 179, 32,
                173, 88, 122, 234, 88, 139, 82, 26, 113, 42, 8, 183, 190, 163, 221, 112>>,
            origin_public_key:
              <<0, 0, 76, 168, 99, 61, 84, 206, 158, 226, 212, 161, 60, 62, 55, 101, 249, 142,
                174, 178, 157, 241, 148, 35, 19, 177, 109, 40, 224, 179, 31, 66, 129, 4>>
          }
        ],
        closest_nodes: [
          %Node{
            ip: {127, 0, 0, 1},
            port: 3000,
            http_port: 4000,
            first_public_key:
              <<0, 0, 182, 67, 168, 252, 227, 203, 142, 164, 142, 248, 159, 209, 249, 247, 86, 64,
                92, 224, 91, 182, 122, 49, 209, 169, 96, 111, 219, 204, 57, 250, 59, 226>>,
            last_public_key:
              <<0, 0, 182, 67, 168, 252, 227, 203, 142, 164, 142, 248, 159, 209, 249, 247, 86, 64,
                92, 224, 91, 182, 122, 49, 209, 169, 96, 111, 219, 204, 57, 250, 59, 226>>,
            geo_patch: "FA9",
            network_patch: "AVC",
            available?: true,
            average_availability: 0.8,
            enrollment_date: ~U[2020-06-26 08:36:11Z],
            authorization_date: ~U[2020-06-26 08:36:11Z],
            authorized?: true,
            reward_address:
              <<0, 0, 163, 237, 233, 93, 14, 241, 241, 8, 144, 218, 105, 16, 138, 243, 223, 17,
                182, 87, 9, 7, 53, 146, 174, 125, 5, 244, 42, 35, 209, 142, 24, 164>>,
            last_address:
              <<0, 0, 165, 32, 187, 102, 112, 133, 38, 17, 232, 54, 228, 173, 254, 94, 179, 32,
                173, 88, 122, 234, 88, 139, 82, 26, 113, 42, 8, 183, 190, 163, 221, 112>>,
            origin_public_key:
              <<0, 0, 76, 168, 99, 61, 84, 206, 158, 226, 212, 161, 60, 62, 55, 101, 249, 142,
                174, 178, 157, 241, 148, 35, 19, 177, 109, 40, 224, 179, 31, 66, 129, 4>>
          }
        ]
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetTransactionChainLength message" do
      address = <<0::8>> <> <<0::8>> <> :crypto.strong_rand_bytes(32)

      msg = %GetTransactionChainLength{
        address: address
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "TransactionChainLength message" do
      msg = %TransactionChainLength{
        length: 1000
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "TransactionInputList message" do
      msg = %TransactionInputList{
        inputs: [
          %TransactionInput{
            from:
              <<0, 0, 147, 31, 74, 190, 86, 56, 43, 83, 35, 166, 128, 254, 235, 43, 129, 108, 57,
                44, 182, 107, 61, 17, 190, 54, 143, 148, 85, 204, 22, 168, 139, 206>>,
            amount: 1_050_000_000,
            spent?: true,
            type: :UCO,
            timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
          },
          %TransactionInput{
            from:
              <<0, 0, 147, 31, 74, 190, 86, 56, 43, 83, 35, 166, 128, 254, 235, 43, 129, 108, 57,
                44, 182, 107, 61, 17, 190, 54, 143, 148, 85, 204, 22, 168, 139, 206>>,
            type: :call,
            timestamp: DateTime.utc_now() |> DateTime.truncate(:second)
          }
        ]
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetP2PView message" do
      msg = %GetP2PView{
        node_public_keys:
          Enum.map(1..10, fn _ ->
            <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
          end)
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "P2PView message" do
      msg = %P2PView{
        nodes_view: <<1::1, 0::1, 1::1, 1::1>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetFirstPublicKey message" do
      msg = %GetFirstPublicKey{
        public_key: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "FirstPublicKey message" do
      msg = %FirstPublicKey{
        public_key: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetLastTransactionAddress message" do
      msg = %GetLastTransactionAddress{
        address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>,
        timestamp: DateTime.truncate(DateTime.utc_now(), :millisecond)
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "LastTransactionAddress message" do
      msg = %LastTransactionAddress{
        address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>,
        timestamp: DateTime.utc_now() |> DateTime.truncate(:millisecond)
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "NotifyLastTransactionAddress message" do
      msg = %NotifyLastTransactionAddress{
        address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>,
        previous_address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>,
        timestamp: DateTime.utc_now() |> DateTime.truncate(:millisecond)
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "GetTransactionSummary message" do
      msg = %GetTransactionSummary{
        address: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "NodeAvailability" do
      msg = %NodeAvailability{
        public_key: <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "Ping message" do
      msg = %Ping{}

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "Error message" do
      msg = %Error{reason: :invalid_transaction}

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end

    test "Register beacon updates" do
      subset = <<0>>
      node_public_key = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>

      msg = %RegisterBeaconUpdates{
        subset: subset,
        node_public_key: node_public_key
      }

      assert msg ==
               msg
               |> Message.encode()
               |> Message.decode()
               |> elem(0)
    end
  end

  test "get_timeout should return timeout according to message type" do
    assert 3_000 == Message.get_timeout(%GetBalance{address: "123"})
    assert 25_165 == Message.get_timeout(%GetTransaction{address: "123"})
  end
end
