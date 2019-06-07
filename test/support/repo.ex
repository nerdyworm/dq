defmodule DQ.Repo do
  use Ecto.Repo, otp_app: :dq, adapter: Ecto.Adapters.Postgres
end
