defmodule Breakfast.MixProject do
  use Mix.Project

  def project do
    [
      app: :breakfast,
      version: "0.1.0",
      elixir: "~> 1.10-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer()
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
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false}
    ]
  end
end
