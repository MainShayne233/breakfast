defmodule Vlad.MixProject do
  use Mix.Project

  def project do
    [
      app: :vlad,
      version: "0.1.0",
      elixir: "~> 1.10-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:mix_test_watch, "~> 0.8", only: :dev, runtime: false}
    ]
  end
end
