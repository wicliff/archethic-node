defmodule UnirisWeb.TopNodeLive do
  use Phoenix.LiveView

  alias UnirisCore.P2P
  alias UnirisCore.P2P.Node
  alias UnirisCore.PubSub

  def mount(_params, _session, socket) do
    if connected?(socket) do
      PubSub.register_to_node_update()
    end

    {:ok, assign(socket, :nodes, top_nodes(P2P.list_nodes()))}
  end

  def render(assigns) do
    Phoenix.View.render(UnirisWeb.ExplorerView, "top_node_list.html", assigns)
  end

  def handle_info({:node_update, node = %Node{}}, socket) do
    new_socket =
      update(socket, :nodes, fn nodes ->
        [node | nodes]
        |> Enum.uniq_by(& &1.first_public_key)
        |> top_nodes
      end)

    {:noreply, new_socket}
  end

  defp top_nodes(nodes) do
    nodes
    |> Enum.filter(& &1.ready?)
    |> Enum.sort_by(& &1.average_availability, :desc)
    |> Enum.take(10)
  end
end