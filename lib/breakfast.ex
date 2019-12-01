defmodule Breakfast do
  @moduledoc Breakfast.Util.hexdocs_from_markdown("README.md")

  alias Breakfast.{Field, Yogurt}

  import Breakfast.Util, only: [maybe_map: 2]

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
    yogurt =
      Enum.reduce(
        mod.__cereal__(:fields),
        %Yogurt{struct: struct(mod), params: params},
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

  @spec cast(term(), Field.t()) :: result(term())
  defp cast(value, %Field{default: {:ok, value}, caster: :default}), do: {:ok, value}

  defp cast(value, %Field{caster: :default, type: {:cereal, module}}) do
    case Breakfast.decode(module, value) do
      %Breakfast.Yogurt{errors: [], struct: struct} ->
        {:ok, struct}

      %Breakfast.Yogurt{errors: [_ | _]} = yogurt ->
        {:ok, yogurt}
    end
  end

  defp cast(value, %Field{caster: :default, type: {:list, type}}) when is_list(value) do
    maybe_map(value, &cast(&1, %Field{caster: :default, type: type}))
  end

  defp cast(value, %Field{caster: :default}), do: {:ok, value}

  defp cast(value, %Field{mod: mod, caster: caster}), do: apply_fn(mod, caster, [value])

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
