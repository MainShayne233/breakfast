##
# this is code used by tests to run certain assertions. it is being compiled
# in lib versus within a test module due to the way Elixir throws out doc/type information
# w/ test modules
if Mix.env() == :test do
  defmodule Breakfast.TestDefinitions do
    @moduledoc false

    defmodule Struct do
      defstruct [:name]
    end

    defmodule OtherStruct do
      defstruct [:email]
    end

    @type status :: :approved | :pending | :rejected

    @type rgb_color :: :red | :green | :blue
    @type cmyk_color :: :cyan | :magenta | :yellow | :black

    @type cycle_a :: cycle_b()
    @type cycle_b :: cycle_a()
  end
end
