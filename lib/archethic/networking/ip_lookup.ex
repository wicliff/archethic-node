defmodule Archethic.Networking.IPLookup do
  @moduledoc false

  require Logger

  alias Archethic.Networking
  alias Archethic.Networking.IPLookup.RemoteDiscovery
  alias Archethic.Networking.IPLookup.NATDiscovery

  @doc """
  Get the node public ip with a fallback capability

  For example, using the NAT provider, if the UPnP discovery failed, it switches to the IPIFY to get the external public ip
  """
  @spec get_node_ip() :: :inet.ip_address()
  def get_node_ip() do
    provider = provider()

    ip =
      with {:ok, ip} <- provider.get_node_ip(),
           :ok <- Networking.validate_ip(ip) do
        Logger.info("Node IP discovered by #{provider}")
        ip
      else
        {:error, reason} ->
          fallback(provider, reason)
      end

    Logger.info("Node IP discovered: #{:inet.ntoa(ip)}")
    ip
  end

  defp fallback(NATDiscovery, reason) do
    Logger.warning("Cannot use NATDiscovery: NAT IP lookup - #{inspect(reason)}")
    Logger.info("Trying PublicGateway: IPIFY as fallback")

    case RemoteDiscovery.get_node_ip() do
      {:ok, ip} ->
        ip

      {:error, reason} ->
        raise "Cannot use remote discovery IP lookup - #{inspect(reason)}"
    end
  end

  defp fallback(provider, reason) do
    raise "Cannot use #{provider} IP lookup - #{inspect(reason)}"
  end

  defp provider() do
    Application.get_env(:archethic, __MODULE__)
  end
end
