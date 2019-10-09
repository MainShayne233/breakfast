defmodule Breakfast.Type do
  @type quoted_module :: {:__aliases__, Keyword.t(), term()}

  @type spec :: term()

  @type type :: term()

  @type predicate :: (value :: term() -> boolean())

  @standard_types_lookup %{
    integer: %{predicate: &__MODULE__.is_integer/1},
    float: %{predicate: &__MODULE__.is_float/1},
    number: %{predicate: &__MODULE__.is_number/1},
    string: %{predicate: &__MODULE__.is_binary/1},
    boolean: %{predicate: &__MODULE__.is_boolean/1},
    nil: %{predicate: &__MODULE__.is_nil/1},
    term: %{predicate: &__MODULE__.is_any/1},
    any: %{predicate: &__MODULE__.is_any/1},
    atom: %{predicate: &__MODULE__.is_atom/1},
    map: %{predicate: &__MODULE__.is_map/1}
  }

  @spec fetch_predicate(spec()) :: {:ok, predicate()} | :error
  def fetch_predicate([list_item_spec]) do
    with {:ok, predicate} <- fetch_predicate(list_item_spec) do
      {:ok, quote(do: fn list -> Enum.all?(&1, unquote(predicate)) end)}
    end
  end

  def fetch_predicate(spec) do
    with {:ok, type} <- type_from_spec(spec),
         %{^type => %{predicate: predicate}} <- @standard_types_lookup do
      {:ok, predicate}
    else
      _ ->
        :error
    end
  end

  @spec type_from_spec(spec()) :: {:ok, type()}
  defp type_from_spec({{:., _, [{:__aliases__, _, [:String]}, :t]}, _, []}), do: {:ok, :string}
  defp type_from_spec({:integer, _, []}), do: {:ok, :integer}

  defp type_from_spec(_other), do: :error

  # weirdly have to wrap these in order to allow for refs to these
  # anonymous functions to be compiled into the module attributes
  defdelegate is_atom(value), to: Kernel
  defdelegate is_integer(value), to: Kernel
  defdelegate is_float(value), to: Kernel
  defdelegate is_number(value), to: Kernel
  defdelegate is_binary(value), to: Kernel
  defdelegate is_boolean(value), to: Kernel
  defdelegate is_nil(value), to: Kernel
  def is_any(_value), do: true
  defdelegate is_map(value), to: Kernel
end
