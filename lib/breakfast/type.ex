defmodule Breakfast.Type do
  @moduledoc false
  alias TypeReader.TerminalType
  alias Breakfast.Field

  @understood_primitive_type_predicate_mappings %{
    any: {__MODULE__, :is_anything},
    term: {__MODULE__, :is_anything},
    keyword: {__MODULE__, :is_keyword},
    struct: {__MODULE__, :is_struct},
    neg_integer: {__MODULE__, :is_neg_integer},
    non_neg_integer: {__MODULE__, :is_non_neg_integer},
    pos_integer: {__MODULE__, :is_pos_integer},
    nonempty_list: {__MODULE__, :is_nonempty_list},
    mfa: {__MODULE__, :is_mfa},
    empty_list: {__MODULE__, :is_empty_list},
    empty_map: {__MODULE__, :is_empty_map},
    map: {Kernel, :is_map},
    boolean: {Kernel, :is_boolean},
    binary: {Kernel, :is_binary},
    integer: {Kernel, :is_integer},
    float: {Kernel, :is_float},
    number: {Kernel, :is_number},
    atom: {Kernel, :is_atom},
    tuple: {Kernel, :is_tuple},
    list: {Kernel, :is_list},
    module: {Kernel, :is_atom}
  }

  @understood_primitive_types Map.keys(@understood_primitive_type_predicate_mappings) ++
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

  @spec derive_from_spec(Macro.t()) :: Field.type() | no_return()
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

  @spec determine_type(%TerminalType{}) :: Breakfast.result(Field.type())
  defp determine_type(%TerminalType{name: :literal, bindings: [value: min..max]}) do
    {:ok, {:range, {min, max}}}
  end

  defp determine_type(%TerminalType{name: :literal, bindings: [value: literal_value]}) do
    {:ok, {:literal, literal_value}}
  end

  defp determine_type(%TerminalType{name: type_name, bindings: []})
       when type_name in @understood_primitive_types do
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
             with {:ok, determined_type} <- determine_type(type),
                  do: {:ok, {key, determined_type}}
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

  defp determine_type(%TerminalType{name: :map, bindings: bindings}) do
    with {:ok, {required, optional}} <- determine_required_and_optional_field_types(bindings) do
      {:ok, {:map, {required, optional}}}
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

  defp determine_required_and_optional_field_types(bindings) do
    maybe_map([:required, :optional], fn require_type ->
      bindings
      |> Keyword.get(require_type, [])
      |> maybe_map(fn {key, value} ->
        with {:ok, key_type} <- determine_type(key),
             {:ok, value_type} <- determine_type(value) do
          {:ok, {key_type, value_type}}
        end
      end)
    end)
    |> case do
      {:ok, [required, optional]} ->
        {:ok, {required, optional}}

      :error ->
        :error
    end
  end

  @spec validate(Field.type(), term()) :: [String.t()]
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
      ["expected one of #{display_type({:union, union_types})}, got: #{inspect(term)}"]
    end
  end

  def validate({:literal, literal_value}, term) do
    if literal_value == term do
      []
    else
      ["expected #{inspect(literal_value)}, got: #{inspect(term)}"]
    end
  end

  # def validate({:nonempty_list, type}, term) do
  #   with {:is_list, true} <- {:is_list, is_list(term)},
  #        {:is_empty, false} <- {:is_empty, Enum.empty?(term)} do
  #     validate({:list, type}, term)
  #   else
  #     {:is_list, false} ->
  #       ["expected a nonempty list, got: #{term}"]

  #     {:is_empty, true} ->
  #       ["expected a nonempty list, got: []"]
  #   end
  # end

  def validate({:nonempty_list, type}, []) do
    ["expected a nonempty_list of type #{display_type(type)}, got: []"]
  end

  def validate({list_type, type}, term) when list_type in [:list, :nonempty_list] do
    with {:is_list, true} <- {:is_list, is_list(term)},
         {:item_errors, []} <- {:item_errors, Enum.flat_map(term, &validate(type, &1))} do
      []
    else
      {:is_list, false} ->
        ["expected a #{list_type} of type #{display_type(type)}, got: #{inspect(term)}"]

      {:item_errors, [_ | _] = errors} ->
        [
          "expected a #{list_type} of type #{display_type(type)}, got a #{list_type} with at least one invalid element: #{
            Enum.join(errors, ", ")
          }"
        ]
    end
  end

  def validate({:keyword, value_type}, term) do
    with true <- is_keyword(term),
         [] <- validate_values(value_type, term) do
      []
    else
      false ->
        [
          "expected a keyword with values of type #{display_type(value_type)}, got: #{
            inspect(term)
          }"
        ]

      [_ | _] = invalidations ->
        [
          "expected a keyword with values of type #{display_type(value_type)}, got: a keyword with invalid values: #{
            inspect(invalidations)
          }"
        ]
    end
  end

  def validate({:map, {required, optional}}, term) do
    with true <- is_map(term),
         [] <- validate_required_map_fields(required, term),
         [] <- validate_optional_map_fields(optional, term) do
      []
    else
      false ->
        ["expected a map, got: #{inspect(term)}"]

      [_ | _] = invalidations ->
        invalidations
    end
  end

  def validate({:struct, {struct_module, required}}, term) do
    with {:struct, %^struct_module{}} <- {:struct, term},
         {:invalidations, []} <-
           {:invalidations,
            validate_required_map_fields(
              Enum.map(required, fn {key, value} -> {{:literal, key}, value} end),
              Map.from_struct(term)
            )} do
      []
    else
      {:struct, _} ->
        ["expected a %#{inspect(struct_module)}{}, got: #{inspect(term)}"]

      {:invalidations, [_ | _] = invalidations} ->
        invalidations
    end
  end

  def validate({:range, {min, max}}, term) do
    if is_integer(term) and term >= min and term <= max do
      []
    else
      ["expected an integer in #{min}..#{max}, got: #{term}"]
    end
  end

  for {type, {predicate_module, predicate_function}} <-
        @understood_primitive_type_predicate_mappings do
    def validate(unquote(type), term) do
      if apply(unquote(predicate_module), unquote(predicate_function), [term]) do
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

  @spec validate_values(Field.type(), keyword()) :: [String.t()]
  defp validate_values({:required, required_fields}, keyword) do
    Enum.reduce(required_fields, [], fn {key, value_type}, acc ->
      with {:ok, value} <- Keyword.fetch(keyword, key),
           [] <- validate(value_type, value) do
        acc
      else
        :error ->
          [{key, ["expected required value for key, but it was not present"]} | acc]

        [_ | _] = invalidations ->
          [{key, invalidations} | acc]
      end
    end)
  end

  defp validate_values(value_type, keyword) do
    Enum.reduce(keyword, [], fn {key, value}, acc ->
      case validate(value_type, value) do
        [] -> acc
        [_ | _] = invalidations -> [{key, invalidations} | acc]
      end
    end)
  end

  @spec validate_required_map_fields([Field.type()], map()) :: [String.t()]
  defp validate_required_map_fields(required, map) do
    Enum.reduce(required, [], fn
      {{:literal, key}, value_type}, acc ->
        with {:ok, value} <- Map.fetch(map, key),
             [] <- validate(value_type, value) do
          acc
        else
          :error ->
            [
              "expected a field with key #{inspect(key)} and value of type #{inspect(value_type)}, but it was not present"
              | acc
            ]

          [_ | _] = invalidations ->
            [
              "expected a field with key #{inspect(key)} and value of type #{inspect(value_type)}, got: invalid value: #{
                inspect(invalidations)
              }"
              | acc
            ]
        end

      {key_type, value_type}, acc ->
        Enum.any?(map, fn {key, value} ->
          case {validate(key_type, key), validate(value_type, value)} do
            {[], []} ->
              true

            _other ->
              false
          end
        end)
        |> case do
          true ->
            acc

          false ->
            []
        end
    end)
  end

  @spec validate_optional_map_fields([Field.type()], map()) :: [String.t()]
  defp validate_optional_map_fields(optional, map) do
    Enum.reduce(optional, [], fn {key, value_type}, acc ->
      with {:ok, value} <- Map.fetch(map, key),
           [] <- validate(value_type, value) do
        acc
      else
        :error ->
          acc

        [_ | _] = invalidations ->
          [{key, invalidations} | acc]
      end
    end)
  end

  @spec display_type(Field.type()) :: String.t()
  defp display_type({:required, required_fields}) do
    displayed_fields =
      Enum.map(required_fields, fn {key, type} ->
        "#{key}: #{display_type(type)}"
      end)
      |> Enum.join(", ")

    "required(#{displayed_fields})"
  end

  defp display_type({:union, types}) do
    types
    |> Enum.map(&display_type/1)
    |> Enum.join(" | ")
  end

  defp display_type({:literal, literal}), do: inspect(literal)

  defp display_type(type), do: inspect(type)

  @spec is_anything(term()) :: true
  def is_anything(_), do: true

  @spec is_keyword(term()) :: boolean()
  def is_keyword(term) do
    is_list(term) and Enum.all?(term, fn {key, _} -> is_atom(key) end)
  end

  @spec is_struct(term()) :: boolean()
  def is_struct(term), do: match?(%_{}, term)

  @spec is_neg_integer(term()) :: boolean()
  def is_neg_integer(term), do: is_integer(term) and term < 0

  @spec is_non_neg_integer(term()) :: boolean()
  def is_non_neg_integer(term), do: is_integer(term) and term >= 0

  @spec is_pos_integer(term()) :: boolean()
  def is_pos_integer(term), do: is_integer(term) and term > 0

  @spec is_nonempty_list(term()) :: boolean()
  def is_nonempty_list(term), do: match?([_ | _], term)

  @spec is_mfa(term()) :: boolean()
  def is_mfa(term) do
    case term do
      {module, function, arity}
      when is_atom(module) and is_atom(function) and is_integer(arity) ->
        true

      _other ->
        false
    end
  end

  @spec is_empty_list(term()) :: boolean()
  def is_empty_list(term), do: match?([], term)

  @spec is_empty_map(term()) :: boolean()
  def is_empty_map(term), do: term == %{}
end
