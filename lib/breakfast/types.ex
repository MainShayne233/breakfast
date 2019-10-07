defmodule Breakfast.Types do
  alias Breakfast.Type

  @type quoted_module :: {:__aliases__, Keyword.t(), term()}

  @type valid_type_def ::
          :integer
          | :float
          | :number
          | :string
          | :boolean
          | nil
          | :atom
          | :map
          | {:array, term()}
          | quoted_module()

  @standard_types [
    %Type{name: :integer, spec: quote(do: integer()), predicate: &__MODULE__.is_integer/1},
    %Type{name: :float, spec: quote(do: float()), predicate: &__MODULE__.is_float/1},
    %Type{name: :number, spec: quote(do: number()), predicate: &__MODULE__.is_number/1},
    %Type{name: :string, spec: quote(do: String.t()), predicate: &__MODULE__.is_binary/1},
    %Type{name: :boolean, spec: quote(do: boolean()), predicate: &__MODULE__.is_boolean/1},
    %Type{name: nil, spec: quote(do: nil), predicate: &__MODULE__.is_nil/1},
    %Type{name: :atom, spec: quote(do: atom()), predicate: &__MODULE__.is_atom/1},
    %Type{name: :map, spec: quote(do: map()), predicate: &__MODULE__.is_map/1}
  ]

  @standard_types_table Enum.into(@standard_types, %{}, &{&1.name, &1})

  @standard_type_names Map.keys(@standard_types_table)

  @doc """
  Returns the static list of standard types
  """
  @spec standard_types :: [Type.t()]
  def standard_types, do: @standard_types

  @doc """
  A guard to check if the given name corresponds to a standard type.
  """
  @spec is_standard_type(value :: atom()) :: term()
  defguard is_standard_type(value) when value in @standard_type_names

  @doc """
  Fetches the standard type for the given name.
  """
  @spec get_standard_type!(name :: atom()) :: Type.t() | no_return()
  def get_standard_type!(name), do: Map.fetch!(@standard_types_table, name)

  # weirdly have to wrap these in order to allow for refs to these
  # anonymous functions to be compiled into the module attributes
  defdelegate is_atom(value), to: Kernel
  defdelegate is_integer(value), to: Kernel
  defdelegate is_float(value), to: Kernel
  defdelegate is_number(value), to: Kernel
  defdelegate is_binary(value), to: Kernel
  defdelegate is_boolean(value), to: Kernel
  defdelegate is_nil(value), to: Kernel
  defdelegate is_map(value), to: Kernel
end
