defmodule Archethic.P2P.MemTableLoader do
  @moduledoc false

  use GenServer

  alias Archethic.Crypto

  alias Archethic.DB

  alias Archethic.P2P
  alias Archethic.P2P.Client
  alias Archethic.P2P.GeoPatch
  alias Archethic.P2P.MemTable
  alias Archethic.P2P.Node

  alias Archethic.SelfRepair
  alias Archethic.SelfRepair.Scheduler, as: SelfRepairScheduler

  alias Archethic.SharedSecrets

  alias Archethic.TransactionChain
  alias Archethic.TransactionChain.Transaction
  alias Archethic.TransactionChain.Transaction.ValidationStamp
  alias Archethic.TransactionChain.TransactionData
  alias Archethic.TransactionChain.TransactionData.Ownership

  alias Crontab.CronExpression.Parser, as: CronParser
  alias Crontab.Scheduler, as: CronScheduler

  require Logger

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    nodes_transactions =
      DB.list_transactions_by_type(:node, [
        :address,
        :type,
        :previous_public_key,
        data: [:content],
        validation_stamp: [:timestamp]
      ])

    node_shared_secret_txs =
      DB.list_transactions_by_type(:node_shared_secrets, [
        :address,
        :type,
        data: [:ownerships],
        validation_stamp: [:timestamp]
      ])

    nodes_transactions
    |> Stream.concat(node_shared_secret_txs)
    |> Stream.filter(& &1)
    |> Enum.sort_by(& &1.validation_stamp.timestamp, {:asc, DateTime})
    |> Enum.each(&load_transaction/1)

    last_repair_time = SelfRepair.last_sync_date()

    unless last_repair_time == nil do
      self_repair_interval =
        :archethic
        |> Application.get_env(SelfRepairScheduler, [])
        |> Keyword.fetch!(:interval)

      last_repair_time = last_repair_time |> DateTime.add(1, :millisecond)

      next_repair_time =
        self_repair_interval
        |> CronParser.parse!(true)
        |> CronScheduler.get_next_run_date!(DateTime.to_naive(last_repair_time))
        |> DateTime.from_naive!("Etc/UTC")

      is_same_slot? = DateTime.compare(DateTime.utc_now(), next_repair_time) == :lt
      # We want to reload the previous beacon chain summary information
      # if the node haven't been disconnected for a significant time (one self-repair cycle)
      # if the node was disconnected for long time, then we don't load the previous view, as it's obsolete
      Enum.each(DB.get_last_p2p_summaries(), fn summary ->
        load_p2p_summary(summary, is_same_slot?)
      end)
    end

    {:ok, %{}}
  end

  @doc """
  Load the transaction and update the P2P view
  """
  @spec load_transaction(Transaction.t()) :: :ok
  def load_transaction(%Transaction{
        address: address,
        type: :node,
        previous_public_key: previous_public_key,
        data: %TransactionData{content: content},
        validation_stamp: %ValidationStamp{
          timestamp: timestamp
        }
      }) do
    Logger.info("Loading transaction into P2P mem table",
      transaction_address: Base.encode16(address),
      transaction_type: :node
    )

    first_public_key = TransactionChain.get_first_public_key(previous_public_key)

    {:ok, ip, port, http_port, transport, reward_address, origin_public_key, _certificate} =
      Node.decode_transaction_content(content)

    if first_node_change?(first_public_key, previous_public_key) do
      node = %Node{
        ip: ip,
        port: port,
        http_port: http_port,
        first_public_key: first_public_key,
        last_public_key: previous_public_key,
        geo_patch: GeoPatch.from_ip(ip),
        transport: transport,
        last_address: address,
        reward_address: reward_address,
        origin_public_key: origin_public_key
      }

      node
      |> Node.enroll(timestamp)
      |> MemTable.add_node()
    else
      {:ok, node} = MemTable.get_node(first_public_key)

      MemTable.add_node(%{
        node
        | ip: ip,
          port: port,
          http_port: http_port,
          last_public_key: previous_public_key,
          geo_patch: GeoPatch.from_ip(ip),
          transport: transport,
          last_address: address,
          reward_address: reward_address,
          origin_public_key: origin_public_key
      })
    end

    Logger.info("Node loaded into in memory p2p tables", node: Base.encode16(first_public_key))

    if first_public_key != Crypto.first_node_public_key() do
      {:ok, _pid} = Client.new_connection(ip, port, transport, first_public_key)
      :ok
    else
      :ok
    end
  end

  def load_transaction(%Transaction{
        address: address,
        type: :node_shared_secrets,
        data: %TransactionData{ownerships: [ownership = %Ownership{}]},
        validation_stamp: %ValidationStamp{
          timestamp: timestamp
        }
      }) do
    Logger.info("Loading transaction into P2P mem table",
      transaction_address: Base.encode16(address),
      transaction_type: :node_shared_secrets
    )

    new_authorized_keys = Ownership.list_authorized_public_keys(ownership)
    previous_authorized_keys = P2P.list_authorized_public_keys()

    unauthorized_keys = previous_authorized_keys -- new_authorized_keys

    Enum.each(unauthorized_keys, &MemTable.unauthorize_node/1)

    new_authorized_keys
    |> Enum.map(&MemTable.get_first_node_key/1)
    |> Enum.each(&MemTable.authorize_node(&1, SharedSecrets.next_application_date(timestamp)))
  end

  def load_transaction(_), do: :ok

  defp first_node_change?(first_key, previous_key) when first_key == previous_key, do: true
  defp first_node_change?(_, _), do: false

  defp load_p2p_summary({node_public_key, {available?, avg_availability}}, is_same_slot?) do
    if available? do
      P2P.set_node_globally_synced(node_public_key)

      if is_same_slot? do
        P2P.set_node_globally_available(node_public_key)
      end
    end

    MemTable.update_node_average_availability(node_public_key, avg_availability)
  end
end
