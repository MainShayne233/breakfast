defmodule Breakfast.MixProject do
  use Mix.Project

  def project do
    [
      app: :breakfast,
      version: "0.1.3",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      name: "Breakfast",
      source_url: "https://github.com/MainShayne233/breakfast",
      homepage_url: "https://github.com/MainShayne233/breakfast",
      docs: [
        main: "Breakfast",
        logo: "logo-white.png",
        extras: ["README.md", "TYPES.md"]
      ]
    ]
  end

  def application do
    []
  end

  defp description, do: "An Elixir decoder-generator library that leans on typespecs"

  defp package do
    [
      name: "breakfast",
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => "https://github.com/MainShayne233/breakfast"}
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/breakfast.plt"}
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.1.4"},
      {:type_reader, "~> 0.0.4"},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.12.0", only: [:dev, :test], runtime: false},
      {:markdown_test, "0.1.2", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
