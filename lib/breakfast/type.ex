defmodule Breakfast.Type do
  @moduledoc false
  alias TypeReader.TerminalType

  @understood_primative_type_predicate_mappings %{
    map: :is_map,
    boolean: :is_boolean,
    binary: :is_binary,
    integer: :is_integer,
    float: :is_float,
    number: :is_number,
    atom: :is_atom
  }

  @understood_primative_types Map.keys(@understood_primative_type_predicate_mappings) ++
                                [
                                  :term,
                                  :any,
                                  :keyword,
                                  :struct,
                                  :tuple,
                                  :neg_integer,
                                  :non_neg_integer,
                                  :pos_integer,
                                  :list,
                                  :nonempty_list,
                                  :mfa,
                                  :module,
                                  :empty_list,
                                  :empty_map
                                ]

  @spec derive_from_spec(Macro.t()) :: Breakfast.Field.type() | no_return()
  def derive_from_spec({:cereal, _} = cereal), do: cereal

  def derive_from_spec(spec) do
    with {:ok, type} <- TypeReader.type_from_quoted(spec),
         {:ok, determined_type} <- determine_type(type) do
      determined_type
    else
      _ ->
        raise Breakfast.TypeError, """


          Failed to derive type `#{Macro.to_string(spec)}` from spec. Did you forget to define it?

          defmodule MyModule do
            @type #{Macro.to_string(spec)} :: some_type()

            cereal do
              ...
            end
          end
        """
    end
  end

  @spec determine_type(%TerminalType{}) :: Breakfast.result(Breakfast.Field.type())
  defp determine_type(%TerminalType{name: :literal, bindings: [value: min..max]}) do
    {:ok, {:range, {min, max}}}
  end

  defp determine_type(%TerminalType{name: :literal, bindings: [value: literal_value]}) do
    {:ok, {:literal, literal_value}}
  end

  defp determine_type(%TerminalType{name: type_name, bindings: []})
       when type_name in @understood_primative_types do
    {:ok, type_name}
  end

  defp determine_type(%TerminalType{
         name: :keyword,
         bindings: [
           type: {:required_keys, required_keys}
         ]
       }) do
    with {:ok, keyed_types} <-
           maybe_map(required_keys, fn {key, type} ->
             with :error <- determine_type(type), do: {key, type}
           end) do
      {:ok, {:keyword, {:required, keyed_types}}}
    end
  end

  defp determine_type(%TerminalType{name: :struct, bindings: [module: module, fields: fields]}) do
    with {:ok, field_types} <-
           maybe_map(fields, fn {key, type} ->
             with {:ok, field_type} <- determine_type(type), do: {:ok, {key, field_type}}
           end) do
      {:ok, {:struct, {module, field_types}}}
    end
  end

  for many_typed_type <- [:union, :tuple] do
    defp determine_type(%TerminalType{
           name: unquote(many_typed_type),
           bindings: [elem_types: elem_types]
         }) do
      with {:ok, determined_elem_types} <- maybe_map(elem_types, &determine_type/1) do
        {:ok, {unquote(many_typed_type), determined_elem_types}}
      end
    end
  end

  for typed_type <- [:list, :nonempty_list, :keyword] do
    defp determine_type(%TerminalType{name: unquote(typed_type), bindings: [type: elem_type]}) do
      with {:ok, determined_elem_type} <- determine_type(elem_type) do
        {:ok, {unquote(typed_type), determined_elem_type}}
      end
    end
  end

  @spec validate(Breakfast.Field.type(), term()) :: [String.t()]
  def validate({:tuple, union_types}, term) do
    with true <- is_tuple(term),
         term_as_list = Tuple.to_list(term),
         true <- length(union_types) == length(term_as_list),
         values_and_types = Enum.zip(term_as_list, union_types),
         true <- Enum.all?(values_and_types, fn {value, type} -> validate(type, value) == [] end) do
      []
    else
      false ->
        ["expected #{inspect(List.to_tuple(union_types))}, got: #{inspect(term)}"]
    end
  end

  def validate({:union, union_types}, term) do
    if Enum.any?(union_types, &(validate(&1, term) == [])) do
      []
    else
      ["expected one of #{inspect(union_types)}, got: #{inspect(term)}"]
    end
  end

  def validate({:literal, literal_value}, term) do
    if literal_value == term do
      []
    else
      ["expected #{literal_value}, got: #{inspect(term)}"]
    end
  end

  def validate({:list, type}, term) when is_list(term) do
    Enum.find_value(term, [], fn t ->
      case validate(type, t) do
        [_ | _] = error ->
          error

        [] ->
          false
      end
    end)
  end

  def validate({:list, _type}, term), do: ["expected a list but got: #{inspect(term)}"]

  for {type, predicate} <- @understood_primative_type_predicate_mappings do
    def validate(unquote(type), term) do
      if apply(Kernel, unquote(predicate), [term]) do
        []
      else
        ["expected a #{unquote(type)}, got: #{inspect(term)}"]
      end
    end
  end

  @spec maybe_map(Enumerable.t(), (term() -> Breakfast.result(term()))) ::
          Breakfast.result([term()])
  defp maybe_map(enum, map) do
    Enum.reduce_while(enum, [], fn value, acc ->
      case map.(value) do
        {:ok, mapped_value} -> {:cont, [mapped_value | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      acc when is_list(acc) -> {:ok, Enum.reverse(acc)}
      :error -> :error
    end
  end
end
