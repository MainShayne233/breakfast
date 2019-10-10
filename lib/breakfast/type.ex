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

  def infer_validator([spec], validators) do
    with {:ok, item_validator} <- infer_validator(spec, validators) do
      {:ok, list_validator(item_validator)}
    end
  end

  def infer_validator(spec, validators) do
    with :error <- fetch_defined_validator(spec, validators),
         {:ok, predicate} <- fetch_predicate(spec) do
      {:ok, validator_from_predicate(predicate)}
    else
      {:ok, defined_validator} ->
        {:ok, defined_validator}

      :error ->
        {:error, spec}
    end
  end

  defp list_validator(item_validator) do
    quote(
      do: fn list ->
        Enum.reduce_while(list, :ok, fn item, :ok ->
          case unquote(item_validator).(item) do
            :ok -> {:cont, :ok}
            :error -> {:halt, :error}
          end
        end)
      end
    )
  end

  defp fetch_defined_validator(spec, validators) do
    Enum.find_value(validators, :error, fn [validator_spec, validator_func] ->
      if Macro.to_string(spec) == Macro.to_string(validator_spec) do
        {:ok, validator_func}
      else
        false
      end
    end)
  end

  defp validator_from_predicate(predicate) do
    quote do
      &if(unquote(predicate).(&1), do: :ok, else: :error)
    end
  end

  defp fetch_predicate(spec) do
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
