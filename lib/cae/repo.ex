defmodule Cae.Repo do
  use Ecto.Repo,
    otp_app: :cae,
    adapter: Ecto.Adapters.Postgres
end
