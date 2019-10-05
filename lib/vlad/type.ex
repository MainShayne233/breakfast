defmodule Vlad.Type do
  @moduledoc """
  Defines the Vlad.Type struct.
  """

  @type t :: %__MODULE__{
          name: atom(),
          spec: term(),
          predicate: (value :: term() -> boolean())
        }

  @enforce_keys [:name, :spec, :predicate]

  defstruct @enforce_keys
end
