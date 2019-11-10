if Mix.env() == :test do
  defmodule Breakfast.TestDefinitions do
    @type status :: :approved | :pending | :rejected
  end
end
