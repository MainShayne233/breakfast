defmodule Vlad.Type do
  @moduledoc """
  Defines the Vlad.Type struct.
  """

  alias Vlad.Types

  @type predicate :: (value :: term() -> boolean())

  @type t :: %__MODULE__{
          name: Types.valid_type_def(),
          spec: term(),
          predicate: predicate()
        }

  @enforce_keys [:name, :spec, :predicate]

  defstruct @enforce_keys
end
