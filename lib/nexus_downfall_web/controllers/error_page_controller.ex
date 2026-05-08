defmodule NexusDownfallWeb.ErrorPageController do
  @moduledoc "Renders the custom sci-fi 404 page."

  use NexusDownfallWeb, :controller

  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> put_view(html: NexusDownfallWeb.ErrorHTML)
    |> render("404.html", current_user: conn.assigns[:current_user], requested_path: conn.request_path)
  end
end
