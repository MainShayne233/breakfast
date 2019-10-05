defmodule Vlad.Types do
  alias Vlad.Type

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

  defmacro standard_types, do: Macro.escape(@standard_types)

  defguard is_standard_type(value) when value in @standard_type_names

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
