defmodule Breakfast.CompileError do
  @moduledoc """
  Raised at compilation time when the cereal cannot be compiled.
  """
  defexception [:message]
end

defmodule Breakfast.TypeError do
  @moduledoc """
  Raised at compilation time when a type cannot be derived.
  """
  defexception [:message]
end
