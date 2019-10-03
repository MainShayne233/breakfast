defmodule Vlad.Types do
  @standard_types [
    integer: %{
      spec: quote(do: integer()),
      predicate: &__MODULE__.is_integer/1
    },
    float: %{
      spec: quote(do: float()),
      predicate: &__MODULE__.is_float/1
    },
    number: %{
      spec: quote(do: number()),
      predicate: &__MODULE__.is_number/1
    },
    string: %{
      spec: quote(do: String.t()),
      predicate: &__MODULE__.is_binary/1
    },
    boolean: %{
      spec: quote(do: boolean()),
      predicate: &__MODULE__.is_boolean/1
    },
    nil: %{
      spec: quote(do: nil),
      predicate: &__MODULE__.is_nil/1
    },
    atom: %{
      spec: quote(do: atom()),
      predicate: &__MODULE__.is_atom/1
    },
    map: %{
      spec: quote(do: map()),
      predicate: &__MODULE__.is_map/1
    }
  ]

  @standard_type_keys Keyword.keys(@standard_types)

  defmacro standard_types, do: Macro.escape(@standard_types)

  defguard is_standard_type(value) when value in @standard_type_keys

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
