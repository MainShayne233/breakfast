defmodule Breakfast.Digest do
  defmodule Field do
    alias Breakfast.Digest.Data
    alias Breakfast.Type

    @type map_resulter :: (term() -> {:ok, term()} | :error)
    @type map_resulter_2 :: (term(), term() -> {:ok, term()} | :error)
    @type resulter :: (term() -> :ok | :error)

    @type t :: %__MODULE__{
            name: atom(),
            type: Type.spec(),
            default: {:ok, term()} | :error,
            parse: map_resulter(),
            cast: map_resulter(),
            validate: resulter(),
            options: Keyword.t(),
            defined_decoder: {:ok, Data.t()} | :error
          }

    @enforce_keys [:name, :type, :default, :parse, :cast, :validate, :options, :defined_decoder]
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
  @spec digest_data(name :: term(), block() | term(), Keyword.t()) :: Data.t()
  def digest_data(name, {:__block__, _, expressions}, options) do
    sections = Enum.group_by(expressions, &elem(&1, 0), &elem(&1, 2))

    datas =
      sections
      |> Map.get(:defdecoder, [])
      |> Enum.map(fn
        [name, [do: block]] -> digest_data(name, block, [])
        [name, options, [do: block]] -> digest_data(name, block, options)
      end)

    validators =
      sections
      |> Map.get(:validate, [])

    fields =
      sections
      |> Map.get(:field, [])
      |> Enum.map(&digest_field(&1, datas, validators, options))

    %Data{
      name: name,
      fields: fields,
      datas: datas
    }
  end

  def digest_data(name, expr, options) do
    digest_data(name, {:__block__, [], [expr]}, options)
  end

  @spec digest_field(list(), [Data.t()], list(), Keyword.t()) :: Field.t()
  defp digest_field([field_name, type | rest], datas, validators, data_options) do
    options = Enum.at(rest, 0, [])

    params =
      [name: field_name, type: type]
      |> digest_defined_decoder(datas)
      |> digest_default(options)
      |> digest_parse(field_name, options, data_options)
      |> digest_cast(field_name, options)
      |> digest_validate(field_name, type, options, validators)
      |> Keyword.put(:options, options)

    struct!(Field, params)
  end

  defp digest_defined_decoder(params, datas) do
    defined_decoder =
      Enum.find_value(datas, :error, fn %Data{name: name} ->
        type_spec = Keyword.fetch!(params, :type)
        expected_type_spec = quote(do: unquote(name).t())

        if Macro.to_string(expected_type_spec) == Macro.to_string(type_spec) do
          {:ok, name}
        else
          false
        end
      end)

    Keyword.put(params, :defined_decoder, defined_decoder)
  end

  defp digest_default(params, options) do
    default = Keyword.fetch(options, :default)
    Keyword.put(params, :default, default)
  end

  defp digest_validate(params, field_name, type, options, validators) do
    validate =
      case Keyword.fetch(options, :validate) do
        {:ok, validate} ->
          quote do
            fn value ->
              with invalid_return when not is_boolean(invalid_return) <- unquote(validate).(value) do
                raise DecodeError.new_bad_validate_return_error(
                        unquote(field_name),
                        invalid_return
                      )
              end
            end
          end

        :error ->
          case Keyword.fetch!(params, :defined_decoder) do
            {:ok, _} ->
              quote(do: fn _ -> true end)

            :error ->
              infer_validator(field_name, type, validators)
          end
      end

    validate_field =
      quote do
        fn value ->
          case unquote(validate).(value) do
            true ->
              :ok

            false ->
              {:error, DecodeError.new_validate_error(unquote(field_name), value)}
          end
        end
      end

    Keyword.put(params, :validate, validate_field)
  end

  defp infer_validator(field_name, type, validators) do
    case Type.infer_validator(type, validators) do
      {:ok, validator} ->
        validator

      {:error, bad_type} ->
        raise CompileError.new_validator_inference_error(field_name, type, bad_type)
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
          case Keyword.fetch!(params, :defined_decoder) do
            {:ok, decoder} ->
              quote(do: &unquote(decoder).decode/1)

            :error ->
              quote(do: &Tuple.append({:ok}, &1))
          end
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

  defp digest_parse(params, field_name, options, data_options) do
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
          case Keyword.fetch(data_options, :default_parse) do
            {:ok, parse} ->
              quote(do: fn params -> unquote(parse).(params, unquote(field_name)) end)

            :error ->
              quote(do: &Map.fetch(&1, unquote(to_string(field_name))))
          end
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
