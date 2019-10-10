defmodule Breakfast.Digest do
  defmodule Field do
    alias Breakfast.Type

    @type map_resulter :: (term() -> {:ok, term()} | :error)
    @type resulter :: (term() -> :ok | :error)

    @type t :: %__MODULE__{
            name: atom(),
            type: Type.spec(),
            default: {:ok, term()} | :error,
            parse: map_resulter(),
            cast: map_resulter(),
            validate: resulter(),
            options: Keyword.t()
          }

    @enforce_keys [:name, :type, :default, :parse, :cast, :validate, :options]
    defstruct @enforce_keys
  end

  defmodule Data do
    @type t :: %__MODULE__{
            name: term(),
            fields: [Field.t()],
            datas: [t()]
          }

    @enforce_keys [:name]
    @keys_with_defaults [fields: [], datas: []]

    defstruct @enforce_keys ++ @keys_with_defaults
  end

  alias Breakfast.{CompileError, DecodeError, Type}

  @type block :: {:__block__, term(), list()}

  @doc """
  Handles parsing the definition and defining a single Data.t() to describe it.
  """
  @spec digest_data(name :: term(), block() | term()) :: Data.t()
  def digest_data(name, {:__block__, _, expressions}) do
    Enum.reduce(expressions, %Data{name: name}, fn
      {:field, _, params}, data ->
        %Data{data | fields: [digest_field(params) | data.fields]}

      {:defdata, _, [name, [do: block]]}, data ->
        %Data{data | datas: [digest_data(name, block) | data.datas]}
    end)
  end

  def digest_data(name, expr) do
    digest_data(name, {:__block__, [], [expr]})
  end

  @spec digest_field(list()) :: Field.t()
  defp digest_field([field_name, type | rest]) do
    options = Enum.at(rest, 0, [])

    params =
      [name: field_name, type: type]
      |> digest_default(options)
      |> digest_parse(field_name, options)
      |> digest_cast(field_name, options)
      |> digest_validate(field_name, type, options)
      |> Keyword.put(:options, options)

    struct!(Field, params)
  end

  defp digest_default(params, options) do
    default = Keyword.fetch(options, :default)
    Keyword.put(params, :default, default)
  end

  defp digest_validate(params, field_name, type, options) do
    validate =
      case Keyword.fetch(options, :validate) do
        {:ok, validate} ->
          quote do
            fn value ->
              case unquote(validate).(value) do
                :ok ->
                  :ok

                :error ->
                  :error

                other ->
                  raise DecodeError.new_bad_validate_return_error(unquote(field_name), other)
              end
            end
          end

        :error ->
          type_derived_validator(field_name, type)
      end

    validate_field =
      quote do
        fn value ->
          case unquote(validate).(value) do
            :ok ->
              :ok

            :error ->
              {:error, DecodeError.new_validate_error(unquote(field_name), value)}
          end
        end
      end

    Keyword.put(params, :validate, validate_field)
  end

  defp type_derived_validator(field_name, type) do
    case Type.fetch_predicate(type) do
      {:ok, predicate} ->
        validator_from_predicate(predicate)

      :error ->
        raise CompileError.new_validator_inference_error(field_name, type)
    end
  end

  defp validator_from_predicate(predicate) do
    quote do
      &if(unquote(predicate).(&1), do: :ok, else: :error)
    end
  end

  defp digest_cast(params, field_name, options) do
    cast =
      case Keyword.fetch(options, :cast) do
        {:ok, cast} ->
          quote do
            fn value ->
              case unquote(cast).(value) do
                {:ok, casted_value} ->
                  {:ok, casted_value}

                :error ->
                  :error

                other ->
                  raise DecodeError.new_bad_cast_return_error(unquote(field_name), other)
              end
            end
          end

        :error ->
          quote(do: &Tuple.append({:ok}, &1))
      end

    cast_field =
      quote do
        fn value ->
          case unquote(cast).(value) do
            {:ok, casted_value} ->
              {:ok, casted_value}

            :error ->
              {:error, DecodeError.new_cast_error(unquote(field_name), value)}
          end
        end
      end

    Keyword.put(params, :cast, cast_field)
  end

  defp digest_parse(params, field_name, options) do
    parse =
      case Keyword.fetch(options, :parse) do
        {:ok, parse} ->
          quote do
            fn params ->
              case unquote(parse).(params) do
                {:ok, value} ->
                  {:ok, value}

                :error ->
                  :error

                other ->
                  raise DecodeError.new_bad_parse_return_error(unquote(field_name), other)
              end
            end
          end

        :error ->
          quote(do: &Map.fetch(&1, unquote(to_string(field_name))))
      end

    parse_field =
      quote do
        fn params ->
          case unquote(parse).(params) do
            {:ok, value} ->
              {:ok, value}

            :error ->
              unquote(
                case Keyword.fetch!(params, :default) do
                  {:ok, default_value} ->
                    {:ok, default_value}

                  :error ->
                    {:error, Macro.escape(DecodeError.new_parse_error(field_name))}
                end
              )
          end
        end
      end

    Keyword.put(params, :parse, parse_field)
  end
end
