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

defmodule Breakfast.FetchError do
  @moduledoc """
  Raised at runtime when a fetcher returns something other than `{:ok, value}` or `:error`.
  """
  defexception [:message, :field, :type, :fetcher]
end

defmodule Breakfast.CastError do
  @moduledoc """
  Raised at runtime when a caster returns something other than `{:ok, value}` or `:error`.
  """
  defexception [:message, :field, :type, :caster]
end

defmodule Breakfast.ValidateError do
  @moduledoc """
  Raised at runtime when a validator returns something other than a list.
  """
  defexception [:message, :field, :type, :validator]
end
