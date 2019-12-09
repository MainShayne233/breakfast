defmodule Breakfast do
  @moduledoc Breakfast.Util.hexdocs_from_markdown("README.md")

  alias Breakfast.{Field, Yogurt}

  @typep result(t) :: Breakfast.Util.result(t)

  defmacro __using__(opts) do
    quote do
      use Breakfast.Using, unquote(opts)
    end
  end

  @doc """
  The function to call when you want to decode some data.

  It requires that you've defined your decoder module and takes the module name as a parameter.

  See the [quick start](#module-quick-start) guide for more on defining and user decoder modules.

  ## Examples

      iex> defmodule Customer do
      ...>   use Breakfast
      ...>
      ...>   cereal do
      ...>     field :id, non_neg_integer()
      ...>     field :email, String.t()
      ...>   end
      ...> end
      ...>
      ...> data = %{
      ...>   "id" => 5,
      ...>   "email" => "leo@aol.com"
      ...> }
      ...>
      ...> Breakfast.decode(Customer, data)
      %Breakfast.Yogurt{
        errors: [],
        params: %{"email" => "leo@aol.com", "id" => 5},
        struct: %Customer{email: "leo@aol.com", id: 5}
      }
  """
  @spec decode(mod :: module(), params :: term()) :: Yogurt.t()
  def decode(mod, params) do
    fields = mod.__cereal__(:fields)

    yogurt =
      Enum.reduce(
        fields,
        %Yogurt{struct: struct(mod), params: params, fields: fields},
        fn %Field{
             name: name,
             fetcher: fetcher,
             caster: caster,
             type: type,
             validator: validator
           } = field,
           %Yogurt{errors: errors, struct: struct} = yogurt ->
          with {:fetch, {:ok, value}} <- {:fetch, fetch(params, field)},
               {:cast, {:ok, cast_value}} <- {:cast, cast(value, field)},
               {:validate, []} <- {:validate, validate(cast_value, field)} do
            %Yogurt{yogurt | struct: %{struct | name => cast_value}}
          else
            {:fetch, :error} ->
              %Yogurt{yogurt | errors: [{name, "value not found"} | errors]}

            {:cast, :error} ->
              %Yogurt{yogurt | errors: [{name, "cast error"} | errors]}

            {:validate, validation_errors} when is_list(validation_errors) ->
              %Yogurt{yogurt | errors: Enum.map(validation_errors, &{name, &1}) ++ errors}

            {:fetch, retval} ->
              raise Breakfast.FetchError,
                message:
                  "Expected fetcher for `#{name}` (`#{inspect(fetcher)}`) to return `{:ok, value}` or `:error`, got: `#{
                    inspect(retval)
                  }`",
                field: name,
                type: type,
                fetcher: fetcher

            {:cast, retval} ->
              raise Breakfast.CastError,
                message:
                  "Expected caster for `#{name}` (`#{inspect(caster)}`) to return `{:ok, value}` or `:error`, got: `#{
                    inspect(retval)
                  }`",
                field: name,
                type: type,
                caster: caster

            {:validate, retval} ->
              raise Breakfast.ValidateError,
                message:
                  "Expected validator for `#{name}` (`#{inspect(validator)}`) to return a list, got: `#{
                    inspect(retval)
                  }`",
                field: name,
                type: type,
                validator: validator
          end
        end
      )

    %Yogurt{yogurt | errors: Enum.reverse(yogurt.errors)}
  end

  @spec fetch(term(), Field.t()) :: result(term())
  defp fetch(params, field) do
    with :error <- do_fetch(params, field), do: field.default
  end

  @spec do_fetch(term(), Field.t()) :: result(term())
  defp do_fetch(params, %Field{name: name, fetcher: :default}) do
    if is_map(params) do
      Map.fetch(params, to_string(name))
    else
      :error
    end
  end

  defp do_fetch(params, %Field{mod: mod, name: name, fetcher: fetcher}),
    do: apply_fn(mod, fetcher, [params, name])

  ##
  # We want to make sure that any nested Breakfast decoders that are a part of the field's type get
  # properly casted using that decoder.
  #
  # In order to do this, we:
  # - Traverse the field's type and find all the places where a value might need to be casted
  #   using a decoder
  # - Iterate through these locations in the type and attempt to cast that part of the value as needed
  #
  # This should properly cast values regardless of how deep in the data structre they are, and do its best
  # to handle cases like: a value 5 levels deep has a union type where one of the union types is a Breakfast decoder.
  @spec cast_any_nested_decoder_values(term(), Field.t()) :: term()
  defp cast_any_nested_decoder_values(value, field) do
    field
    |> find_all_nested_decoder_paths_in_type()
    |> Enum.reduce(value, &do_cast_any_nested_decoder_values/2)
  end

  @spec do_cast_any_nested_decoder_values({list(), term()}, term(), boolean()) :: term()
  defp do_cast_any_nested_decoder_values(path_and_type, value, strict? \\ true)

  defp do_cast_any_nested_decoder_values({[], {:cereal, module}}, value, strict?) do
    with value when not is_nil(value) <- value,
         %Yogurt{errors: [], struct: struct} <- Breakfast.decode(module, value) do
      struct
    else
      nil ->
        if strict?,
          do: %Yogurt{
            errors: ["value that was expected to cast to a #{inspect(module)}.t() was nil"]
          },
          else: value

      %Yogurt{errors: [_ | _]} = yogurt ->
        if strict?, do: yogurt, else: value
    end
  end

  defp do_cast_any_nested_decoder_values({[:list | rest], type}, value, strict?) do
    Enum.map(value, &do_cast_any_nested_decoder_values({rest, type}, &1, strict?))
  end

  defp do_cast_any_nested_decoder_values({[{:tuple, index} | rest], type}, value, strict?) do
    value
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.map(fn
      {value, ^index} ->
        do_cast_any_nested_decoder_values({rest, type}, value, strict?)

      {value, _} ->
        value
    end)
    |> List.to_tuple()
  end

  defp do_cast_any_nested_decoder_values(
         {[{:map, {require_type, key_type}} | rest], type},
         value,
         strict?
       )
       when is_map(value) do
    value
    |> Enum.map(fn {key, value} ->
      if Breakfast.Type.validate(key_type, key) == [] do
        {key,
         do_cast_any_nested_decoder_values(
           {rest, type},
           value,
           strict? and require_type == :required
         )}
      else
        {key, value}
      end
    end)
    |> Enum.into(%{})
  end

  defp do_cast_any_nested_decoder_values({[:union | rest], type}, value, _strict?) do
    do_cast_any_nested_decoder_values({rest, type}, value, false)
  end

  defp do_cast_any_nested_decoder_values(_path, value, _strict?), do: value

  @spec find_all_nested_decoder_paths_in_type(Field.t()) :: [{list(), term()}]
  defp find_all_nested_decoder_paths_in_type(field) do
    field
    |> do_find_all_nested_decoder_paths_in_type(field.type, [], [])
    |> Enum.map(fn {path, type} -> {Enum.reverse(path), type} end)
  end

  @spec do_find_all_nested_decoder_paths_in_type(Field.t(), term(), list(), list()) :: [
          {term(), term()}
        ]
  defp do_find_all_nested_decoder_paths_in_type(field, type, current_path, paths)

  defp do_find_all_nested_decoder_paths_in_type(
         _field,
         {:cereal, _} = cereal,
         current_path,
         paths
       ) do
    [{current_path, cereal} | paths]
  end

  defp do_find_all_nested_decoder_paths_in_type(field, {:list, type}, current_path, paths) do
    field
    |> do_find_all_nested_decoder_paths_in_type(type, [:list | current_path], paths)
    |> Enum.concat(paths)
  end

  defp do_find_all_nested_decoder_paths_in_type(field, {:tuple, types}, current_path, paths) do
    types
    |> Enum.with_index()
    |> Enum.flat_map(fn {type, index} ->
      do_find_all_nested_decoder_paths_in_type(
        field,
        type,
        [{:tuple, index} | current_path],
        paths
      )
    end)
    |> Enum.concat(paths)
  end

  defp do_find_all_nested_decoder_paths_in_type(
         field,
         {:map, {required, optional}},
         current_path,
         paths
       ) do
    required_paths =
      Enum.flat_map(required, fn {key_type, value_type} ->
        do_find_all_nested_decoder_paths_in_type(
          field,
          value_type,
          [{:map, {:required, key_type}} | current_path],
          paths
        )
      end)

    optional_paths =
      Enum.flat_map(optional, fn {key_type, value_type} ->
        do_find_all_nested_decoder_paths_in_type(
          field,
          value_type,
          [{:map, {:optional, key_type}} | current_path],
          paths
        )
      end)

    required_paths ++ optional_paths ++ paths
  end

  defp do_find_all_nested_decoder_paths_in_type(field, {:union, types}, current_path, paths) do
    types
    |> Enum.flat_map(fn type ->
      do_find_all_nested_decoder_paths_in_type(
        field,
        type,
        [:union | current_path],
        paths
      )
    end)
    |> Enum.concat(paths)
  end

  defp do_find_all_nested_decoder_paths_in_type(_field, _type, _current_path, _paths), do: []

  @spec cast(term(), Field.t()) :: result(term())
  defp cast(value, field) do
    value
    |> cast_any_nested_decoder_values(field)
    |> do_cast(field)
  end

  @spec do_cast(term(), Field.t()) :: result(term())
  defp do_cast(value, %Field{default: {:ok, value}, caster: :default}), do: {:ok, value}

  defp do_cast(value, %Field{caster: :default}), do: {:ok, value}

  defp do_cast(value, %Field{mod: mod, caster: caster}), do: apply_fn(mod, caster, [value])

  @spec validate(term(), Field.t()) :: [String.t()]
  defp validate(value, %Field{validator: :default, type: type}),
    do: Breakfast.Type.validate(type, value)

  defp validate(value, %Field{mod: mod, validator: validator}),
    do: apply_fn(mod, validator, [value])

  @spec apply_fn(module(), fun() | {atom(), keyword()} | atom(), [term()]) :: term()
  defp apply_fn(_mod, fun, [arg1]) when is_function(fun, 1), do: fun.(arg1)
  defp apply_fn(_mod, fun, [arg1, arg2]) when is_function(fun, 2), do: fun.(arg1, arg2)

  defp apply_fn(_mod, fun, [arg1, arg2, arg3]) when is_function(fun, 3),
    do: fun.(arg1, arg2, arg3)

  defp apply_fn(mod, {fun, opts}, args) when is_atom(fun) and is_list(args) and is_list(opts),
    do: apply(mod, fun, args ++ [opts])

  defp apply_fn(mod, fun, args) when is_atom(fun) and is_list(args), do: apply(mod, fun, args)

  defp apply_fn(_mod, {mod, {fun, opts}}, args)
       when is_atom(mod) and is_atom(fun) and is_list(args) and is_list(opts),
       do: apply(mod, fun, args ++ [opts])

  defp apply_fn(_mod, {mod, fun}, args) when is_atom(mod) and is_atom(fun) and is_list(args),
    do: apply(mod, fun, args)
end
