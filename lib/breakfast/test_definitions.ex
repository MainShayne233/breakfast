##
# this is code used by tests to run certain assertions. it is being compiled
# in lib versus within a test module due to the way Elixir throws out doc/type information
# w/ test modules
defmodule Breakfast.TestDefinitions do
  @moduledoc false

  defmodule Struct do
    defstruct [:name]
  end

  @type status :: :approved | :pending | :rejected

  @type rgb_color :: :red | :green | :blue
  @type cmyk_color :: :cyan | :magenta | :yellow | :black
end
