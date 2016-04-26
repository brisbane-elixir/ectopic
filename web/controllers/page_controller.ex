defmodule Ectopic.PageController do
  use Ectopic.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
