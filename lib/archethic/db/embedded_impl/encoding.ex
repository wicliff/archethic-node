defmodule Archethic.DB.EmbeddedImpl.Encoding do
  @moduledoc """
  Handle the encoding and decoding of the transaction and its fields
  """

  alias Archethic.TransactionChain.Transaction
  alias Archethic.TransactionChain.TransactionData
  alias Archethic.TransactionChain.TransactionData.Ledger
  alias Archethic.TransactionChain.TransactionData.Ownership
  alias Archethic.TransactionChain.TransactionData.UCOLedger
  alias Archethic.TransactionChain.TransactionData.TokenLedger
  alias Archethic.TransactionChain.Transaction.ValidationStamp
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations
  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.UnspentOutput

  alias Archethic.TransactionChain.Transaction.ValidationStamp.LedgerOperations.TransactionMovement

  alias Archethic.TransactionChain.Transaction.CrossValidationStamp

  alias Archethic.Utils
  alias Archethic.Utils.VarInt

  @doc """
  Encode a transaction
  """
  @spec encode(Transaction.t()) :: binary()
  def encode(%Transaction{
        version: 1,
        address: address,
        type: type,
        data: %TransactionData{
          content: content,
          code: code,
          ownerships: ownerships,
          ledger: %Ledger{uco: uco_ledger, token: token_ledger},
          recipients: recipients
        },
        previous_public_key: previous_public_key,
        previous_signature: previous_signature,
        origin_signature: origin_signature,
        validation_stamp: %ValidationStamp{
          timestamp: timestamp,
          proof_of_work: proof_of_work,
          proof_of_integrity: proof_of_integrity,
          proof_of_election: proof_of_election,
          ledger_operations: %LedgerOperations{
            fee: fee,
            transaction_movements: transaction_movements,
            unspent_outputs: unspent_outputs
          },
          recipients: resolved_recipients,
          signature: validation_stamp_sig,
          protocol_version: protocol_version
        },
        cross_validation_stamps: cross_validation_stamps
      }) do
    ownerships_encoding =
      ownerships
      |> Enum.map(&Ownership.serialize/1)
      |> :erlang.list_to_binary()

    transaction_movements_encoding =
      transaction_movements
      |> Enum.map(&TransactionMovement.serialize/1)
      |> :erlang.list_to_binary()

    unspent_outputs_encoding =
      unspent_outputs
      |> Enum.map(&UnspentOutput.serialize/1)
      |> :erlang.list_to_binary()

    cross_validation_stamps_encoding =
      cross_validation_stamps
      |> Enum.map(&CrossValidationStamp.serialize/1)
      |> :erlang.list_to_binary()

    encoded_recipients_len = length(recipients) |> VarInt.from_value()
    encoded_ownerships_len = length(ownerships) |> VarInt.from_value()

    encoded_transaction_movements_len = length(transaction_movements) |> VarInt.from_value()

    encoded_unspent_outputs_len = length(unspent_outputs) |> VarInt.from_value()

    encoded_resolved_recipients_len = length(resolved_recipients) |> VarInt.from_value()

    encoding =
      [
        {"address", address},
        {"type", <<Transaction.serialize_type(type)::8>>},
        {"data.content", content},
        {"data.code", code},
        {"data.ledger.uco", UCOLedger.serialize(uco_ledger)},
        {"data.ledger.token", TokenLedger.serialize(token_ledger)},
        {"data.ownerships", <<encoded_ownerships_len::binary, ownerships_encoding::binary>>},
        {"data.recipients",
         <<encoded_recipients_len::binary, :erlang.list_to_binary(recipients)::binary>>},
        {"previous_public_key", previous_public_key},
        {"previous_signature", previous_signature},
        {"origin_signature", origin_signature},
        {"validation_stamp.timestamp", <<DateTime.to_unix(timestamp, :millisecond)::64>>},
        {"validation_stamp.proof_of_work", proof_of_work},
        {"validation_stamp.proof_of_election", proof_of_election},
        {"validation_stamp.proof_of_integrity", proof_of_integrity},
        {"validation_stamp.ledger_operations.transaction_movements",
         <<encoded_transaction_movements_len::binary, transaction_movements_encoding::binary>>},
        {"validation_stamp.ledger_operations.unspent_outputs",
         <<encoded_unspent_outputs_len::binary, unspent_outputs_encoding::binary>>},
        {"validation_stamp.ledger_operations.fee", <<fee::64>>},
        {"validation_stamp.recipients",
         <<encoded_resolved_recipients_len::binary,
           :erlang.list_to_binary(resolved_recipients)::binary>>},
        {"validation_stamp.signature", validation_stamp_sig},
        {"validation_stamp.protocol_version", <<protocol_version::32>>},
        {"cross_validation_stamps",
         <<length(cross_validation_stamps)::8, cross_validation_stamps_encoding::binary>>}
      ]
      |> Enum.map(fn {column, value} ->
        <<byte_size(column)::8, byte_size(value)::32, column::binary, value::binary>>
      end)

    binary_encoding = :erlang.list_to_binary(encoding)
    tx_size = byte_size(binary_encoding)
    <<tx_size::32, 1::32, binary_encoding::binary>>
  end

  def decode(_version, "type", <<type::8>>, acc),
    do: Map.put(acc, :type, Transaction.parse_type(type))

  def decode(_version, "data.content", content, acc) do
    put_in(acc, [Access.key(:data, %{}), :content], content)
  end

  def decode(_version, "data.code", code, acc) do
    put_in(acc, [Access.key(:data, %{}), :code], code)
  end

  def decode(_version, "data.ownerships", <<rest::binary>>, acc) do
    {nb, rest} = rest |> VarInt.get_value()
    ownerships = deserialize_ownerships(rest, nb, [])
    put_in(acc, [Access.key(:data, %{}), :ownerships], ownerships)
  end

  def decode(_version, "data.ledger.uco", data, acc) do
    {uco_ledger, _} = UCOLedger.deserialize(data)
    put_in(acc, [Access.key(:data, %{}), Access.key(:ledger, %{}), :uco], uco_ledger)
  end

  def decode(_version, "data.ledger.token", data, acc) do
    {token_ledger, _} = TokenLedger.deserialize(data)
    put_in(acc, [Access.key(:data, %{}), Access.key(:ledger, %{}), :token], token_ledger)
  end

  def decode(_version, "data.recipients", <<1::8, 0::8>>, acc), do: acc

  def decode(_version, "data.recipients", <<rest::binary>>, acc) do
    {nb, rest} = rest |> VarInt.get_value()
    {recipients, _} = Utils.deserialize_addresses(rest, nb, [])
    put_in(acc, [Access.key(:data, %{}), :recipients], recipients)
  end

  def decode(_version, "validation_stamp.timestamp", <<timestamp::64>>, acc) do
    put_in(
      acc,
      [Access.key(:validation_stamp, %{}), :timestamp],
      DateTime.from_unix!(timestamp, :millisecond)
    )
  end

  def decode(_version, "validation_stamp.proof_of_work", pow, acc) do
    put_in(acc, [Access.key(:validation_stamp, %{}), :proof_of_work], pow)
  end

  def decode(_version, "validation_stamp.proof_of_integrity", poi, acc) do
    put_in(acc, [Access.key(:validation_stamp, %{}), :proof_of_integrity], poi)
  end

  def decode(_version, "validation_stamp.proof_of_election", poe, acc) do
    put_in(acc, [Access.key(:validation_stamp, %{}), :proof_of_election], poe)
  end

  def decode(_version, "validation_stamp.ledger_operations.fee", <<fee::64>>, acc) do
    put_in(
      acc,
      [Access.key(:validation_stamp, %{}), Access.key(:ledger_operations, %{}), :fee],
      fee
    )
  end

  def decode(
        1,
        "validation_stamp.ledger_operations.transaction_movements",
        <<rest::binary>>,
        acc
      ) do
    {nb, rest} = rest |> VarInt.get_value()
    tx_movements = deserialize_transaction_movements(rest, nb, [])

    put_in(
      acc,
      [
        Access.key(:validation_stamp, %{}),
        Access.key(:ledger_operations, %{}),
        :transaction_movements
      ],
      tx_movements
    )
  end

  def decode(
        _version,
        "validation_stamp.ledger_operations.unspent_outputs",
        <<rest::binary>>,
        acc
      ) do
    {nb, rest} = rest |> VarInt.get_value()
    utxos = deserialize_unspent_outputs(rest, nb, [])

    put_in(
      acc,
      [Access.key(:validation_stamp, %{}), Access.key(:ledger_operations, %{}), :unspent_outputs],
      utxos
    )
  end

  def decode(_version, "validation_stamp.recipients", <<rest::binary>>, acc) do
    {nb, rest} = rest |> VarInt.get_value()
    {recipients, _} = Utils.deserialize_addresses(rest, nb, [])
    put_in(acc, [Access.key(:validation_stamp, %{}), :recipients], recipients)
  end

  def decode(_version, "validation_stamp.signature", data, acc) do
    put_in(acc, [Access.key(:validation_stamp, %{}), :signature], data)
  end

  def decode(_version, "validation_stamp.protocol_version", <<version::32>>, acc) do
    put_in(acc, [Access.key(:validation_stamp, %{}), :protocol_version], version)
  end

  def decode(_version, "cross_validation_stamps", <<nb::8, rest::bitstring>>, acc) do
    stamps = deserialize_cross_validation_stamps(rest, nb, [])
    Map.put(acc, :cross_validation_stamps, stamps)
  end

  def decode(_version, column, data, acc), do: Map.put(acc, column, data)

  defp deserialize_ownerships(_, 0, _), do: []

  defp deserialize_ownerships(_, nb, acc) when length(acc) == nb do
    Enum.reverse(acc)
  end

  defp deserialize_ownerships(rest, nb, acc) do
    {ownership, rest} = Ownership.deserialize(rest)
    deserialize_ownerships(rest, nb, [ownership | acc])
  end

  defp deserialize_unspent_outputs(_, 0, _), do: []

  defp deserialize_unspent_outputs(_, nb, acc) when length(acc) == nb do
    Enum.reverse(acc)
  end

  defp deserialize_unspent_outputs(rest, nb, acc) do
    {utxo, rest} = UnspentOutput.deserialize(rest)
    deserialize_unspent_outputs(rest, nb, [utxo | acc])
  end

  defp deserialize_transaction_movements(_, 0, _), do: []

  defp deserialize_transaction_movements(_, nb, acc) when length(acc) == nb do
    Enum.reverse(acc)
  end

  defp deserialize_transaction_movements(rest, nb, acc) do
    {tx_movement, rest} = TransactionMovement.deserialize(rest)
    deserialize_transaction_movements(rest, nb, [tx_movement | acc])
  end

  defp deserialize_cross_validation_stamps(_, 0, _), do: []

  defp deserialize_cross_validation_stamps(_rest, nb, acc) when length(acc) == nb do
    Enum.reverse(acc)
  end

  defp deserialize_cross_validation_stamps(rest, nb, acc) do
    {stamp, rest} = CrossValidationStamp.deserialize(rest)
    deserialize_cross_validation_stamps(rest, nb, [stamp | acc])
  end
end
