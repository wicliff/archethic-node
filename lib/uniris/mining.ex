defmodule Uniris.Mining do
  @moduledoc """
  Handle the ARCH consensus behavior and transaction mining
  """

  alias Uniris.Crypto

  alias Uniris.Election

  alias __MODULE__.DistributedWorkflow
  alias __MODULE__.PendingTransactionValidation
  alias __MODULE__.StandaloneWorkflow
  alias __MODULE__.WorkerSupervisor
  alias __MODULE__.WorkflowRegistry

  alias Uniris.P2P
  alias Uniris.P2P.Node

  alias Uniris.TransactionChain.Transaction
  alias Uniris.TransactionChain.Transaction.CrossValidationStamp
  alias Uniris.TransactionChain.Transaction.ValidationStamp

  @doc """
  Start mining process for a given transaction.
  """
  @spec start(
          transaction :: Transaction.t(),
          welcome_node_public_key :: Crypto.key(),
          validation_node_public_keys :: list(Crypto.key())
        ) :: {:ok, pid()}
  def start(tx = %Transaction{}, welcome_node_public_key, [_ | []]) do
    StandaloneWorkflow.start_link(
      transaction: tx,
      welcome_node: welcome_node_public_key,
      validation_nodes: [P2P.get_node_info()],
      node_public_key: Crypto.node_public_key()
    )
  end

  def start(tx = %Transaction{}, welcome_node_public_key, validation_node_public_keys)
      when is_binary(welcome_node_public_key) and is_list(validation_node_public_keys) do
    DynamicSupervisor.start_child(WorkerSupervisor, {
      DistributedWorkflow,
      transaction: tx,
      welcome_node: P2P.get_node_info!(welcome_node_public_key),
      validation_nodes: Enum.map(validation_node_public_keys, &P2P.get_node_info!/1),
      node_public_key: Crypto.node_public_key()
    })
  end

  @doc """
  Return the list of validation nodes for a given transaction and the current validation constraints
  """
  @spec transaction_validation_nodes(Transaction.t()) :: list(Node.t())
  def transaction_validation_nodes(tx = %Transaction{timestamp: timestamp}) do
    constraints = Election.get_validation_constraints()

    node_list =
      P2P.list_nodes(authorized?: true, availability: :global)
      |> Enum.filter(&(DateTime.diff(timestamp, &1.authorization_date) > 0))

    Election.validation_nodes(tx, node_list, constraints)
  end

  @doc """
  Determines if the election of validation nodes performed by the welcome node is valid
  """
  @spec valid_election?(Transaction.t(), list(Crypto.key())) :: boolean()
  def valid_election?(tx = %Transaction{}, validation_node_public_keys)
      when is_list(validation_node_public_keys) do
    nodes = transaction_validation_nodes(tx)
    Enum.all?(nodes, &(&1.last_public_key in validation_node_public_keys))
  end

  @doc """
  Add transaction mining context which built by another cross validation node
  """
  @spec add_mining_context(
          address :: binary(),
          validation_node_public_key :: Crypto.key(),
          previous_storage_nodes_keys :: list(Crypto.key()),
          cross_validation_nodes_view :: bitstring(),
          chain_storage_nodes_view :: bitstring(),
          beacon_storage_nodes_view :: bitstring()
        ) ::
          :ok
  def add_mining_context(
        tx_address,
        validation_node_public_key,
        previous_storage_nodes_keys,
        cross_validation_nodes_view,
        chain_storage_nodes_view,
        beacon_storage_nodes_view
      ) do
    tx_address
    |> get_mining_process!()
    |> DistributedWorkflow.add_mining_context(
      validation_node_public_key,
      P2P.get_nodes_info(previous_storage_nodes_keys),
      cross_validation_nodes_view,
      chain_storage_nodes_view,
      beacon_storage_nodes_view
    )
  end

  @doc """
  Cross validate the validation stamp and the replication tree produced by the coordinator

  If no inconsistencies, the validation stamp is stamped by the the node public key.
  Otherwise the inconsistencies will be signed.
  """
  @spec cross_validate(
          address :: binary(),
          ValidationStamp.t(),
          replication_tree :: list(bitstring())
        ) :: :ok
  def cross_validate(tx_address, stamp = %ValidationStamp{}, replication_tree)
      when is_list(replication_tree) do
    tx_address
    |> get_mining_process!()
    |> DistributedWorkflow.cross_validate(stamp, replication_tree)
  end

  @doc """
  Add a cross validation stamp to the transaction mining process
  """
  @spec add_cross_validation_stamp(binary(), stamp :: CrossValidationStamp.t()) :: :ok
  def add_cross_validation_stamp(tx_address, stamp = %CrossValidationStamp{}) do
    tx_address
    |> get_mining_process!()
    |> DistributedWorkflow.add_cross_validation_stamp(stamp)
  end

  defp get_mining_process!(tx_address, sleep_time \\ 200, retries \\ 0, max_retries \\ 5)

  defp get_mining_process!(_, _, retries, max_retries) when retries == max_retries do
    raise "No mining process for the transaction"
  end

  defp get_mining_process!(tx_address, sleep_time, retries, max_retries) do
    case Registry.lookup(WorkflowRegistry, tx_address) do
      [{pid, _}] ->
        pid

      _ ->
        Process.sleep(sleep_time)
        get_mining_process!(tx_address, sleep_time, retries + 1, max_retries)
    end
  end

  @doc """
  Validate a pending transaction
  """
  @spec validate_pending_transaction(Transaction.t()) :: :ok | {:error, any()}
  defdelegate validate_pending_transaction(tx), to: PendingTransactionValidation, as: :validate
end
