if Mix.env() == :test do
  defmodule Breakfast.TestDefinitions do
    @type status :: :approved | :pending | :rejected

    @type rgb_color :: :red | :green | :blue
    @type cmyk_color :: :cyan | :magenta | :yellow | :black
  end
end
