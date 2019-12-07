defmodule DQ.Mixfile do
  use Mix.Project

  def project do
    [
      app: :dq,
      version: "0.1.0",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/adapters"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:gen_stage, "~> 0.14"},

      # for admin
      {:plug, ">= 1.0.0"},
      {:cors_plug, ">= 1.0.0"},

      # Ecto Adapter
      {:postgrex, ">= 0.0.0", optional: true},
      {:ecto, ">= 0.0.0", optional: true},
      {:ecto_sql, ">= 0.0.0", optional: true},

      # AWS Sqs
      {:ex_aws, ">=  0.0.0"},
      {:ex_aws_sqs, ">= 0.0.0"},
      {:poison, "~> 4.0"},
      {:hackney, "~> 1.15"},
      {:sweet_xml, ">= 0.5.0"},

      # error reporting and metrics
      {:telemetry, "~> 0.4"}
    ]
  end
end
