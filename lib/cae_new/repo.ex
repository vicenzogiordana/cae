defmodule CaeNew.Repo do
  use Ecto.Repo,
    otp_app: :cae_new,
    adapter: Ecto.Adapters.Postgres
end
