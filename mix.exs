defmodule Breakfast.MixProject do
  use Mix.Project

  def project do
    [
      app: :breakfast,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
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

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/breakfast.plt"}
    ]
  end

  defp deps do
    [
      {:typed_struct, "~> 0.1.4"},
      {:type_reader, github: "MainShayne233/type_reader"},
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.12.0", only: [:dev, :test], runtime: false},
      {:markdown_test, "0.1.1", only: :test},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
