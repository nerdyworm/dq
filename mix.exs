defmodule DQ.Mixfile do
  use Mix.Project

  def project do
    [app: :dq,
     version: "0.1.0",
     elixir: "~> 1.4",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support", "test/adapters"]
  defp elixirc_paths(_),     do: ["lib"]

  defp deps do
    [
      {:gen_stage, "~> 0.12.2"},
      {:poison, ">= 0.0.0"},

      # for admin
      {:plug, ">= 1.0.0"},
      {:cors_plug, ">= 1.0.0"},

      # Ecto Adapter
      {:postgrex, ">= 0.0.0", optional: true},
      {:ecto, "~> 2.1.0", optional: true},

      # Sqso
      {:ex_aws, ">= 1.1.0"},
      {:hackney, ">= 1.7.0", override: true},
      {:sweet_xml, ">= 0.5.0"},
    ]
  end
end
