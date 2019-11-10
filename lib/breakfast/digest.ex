defmodule Breakfast.Digest do
  defmodule Field do
    alias Breakfast.Digest.Decoder
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
            defined_decoder: {:ok, Decoder.t()} | :error
          }

    @enforce_keys [:name, :type, :default, :parse, :cast, :validate, :options, :defined_decoder]
    defstruct @enforce_keys
  end

  defmodule Decoder do
    @type t :: %__MODULE__{
            name: term(),
            fields: [Field.t()],
            decoders: [t()]
          }

    @enforce_keys [:name]
    @keys_with_defaults [fields: [], decoders: []]

    defstruct @enforce_keys ++ @keys_with_defaults
  end

  alias Breakfast.{CompileError, ErrorContext, Type}

  @type block :: {:__block__, term(), list()}

  @doc """
  Handles parsing the definition and defining a single Decoder.t() to describe it.
  """
  @spec digest_decoder(name :: term(), block() | term(), Keyword.t()) :: Decoder.t()
  def digest_decoder(name, {:__block__, _, expressions}, options) do
    sections = Enum.group_by(expressions, &elem(&1, 0), &elem(&1, 2))

    decoders =
      sections
      |> Map.get(:cereal, [])
      |> Enum.map(fn
        [name, [do: block]] -> digest_decoder(name, block, [])
        [name, options, [do: block]] -> digest_decoder(name, block, options)
      end)

    validators =
      sections
      |> Map.get(:validate, [])

    fields =
      sections
      |> Map.get(:field, [])
      |> Enum.map(&digest_field(&1, decoders, validators, options))

    %Decoder{
      name: name,
      fields: fields,
      decoders: decoders
    }
  end

  def digest_decoder(name, expr, options) do
    digest_decoder(name, {:__block__, [], [expr]}, options)
  end

  @spec digest_field(list(), [Decoder.t()], list(), Keyword.t()) :: Field.t()
  defp digest_field([field_name, type | rest], decoders, validators, decoder_options) do
    options = Enum.at(rest, 0, [])

    params =
      [name: field_name, type: type]
      |> digest_defined_decoder(decoders)
      |> digest_default(options)
      |> digest_parse(field_name, options, decoder_options)
      |> digest_cast(options)
      |> digest_validate(field_name, type, options, validators)
      |> Keyword.put(:options, options)

    struct!(Field, params)
  end

  def digest_field_(name, type, options) do
    params =
      [name: name, type: type]
      |> digest_defined_decoder([])
      |> digest_default(options)
      |> digest_parse(name, options, [])
      |> digest_cast(options)
      |> digest_validate(name, type, options, [])
      |> Keyword.put(:options, options)

    struct!(Field, params)
  end

  defp digest_defined_decoder(params, decoders) do
    defined_decoder =
      case Keyword.fetch!(params, :type) do
        {:external, {{:., _, [name, _]}, _, _}} ->
          {:ok, name}

        type ->
          Enum.find_value(decoders, :error, fn %Decoder{name: name} ->
            expected_type_spec = quote(do: unquote(name).t())

            if Macro.to_string(expected_type_spec) == Macro.to_string(type) do
              {:ok, name}
            else
              false
            end
          end)
      end

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
                {:error, %ErrorContext{error_type: :bad_validate_return},
                 problem_value: invalid_return}
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

    validate_field = result_wrap(validate, {true, :ok}, {false, :validate_error})

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

  defp digest_cast(params, options) do
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

                invalid_return ->
                  {:error,
                   %ErrorContext{
                     error_type: :bad_cast_return,
                     problem_value: invalid_return
                   }}
              end
            end
          end

        :error ->
          case Keyword.fetch!(params, :defined_decoder) do
            {:ok, decoder} ->
              quote(do: &unquote(decoder).__decode__(&1))

            :error ->
              quote(do: &Tuple.append({:ok}, &1))
          end
      end

    cast_field =
      result_wrap(cast, {quote(do: {:ok, value}), quote(do: {:ok, value})}, {:error, :cast_error})

    Keyword.put(params, :cast, cast_field)
  end

  defp digest_parse(params, field_name, options, decoder_options) do
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

                invalid_return ->
                  {:error,
                   %ErrorContext{
                     error_type: :bad_parse_return,
                     problem_value: invalid_return
                   }}
              end
            end
          end

        :error ->
          case Keyword.fetch(decoder_options, :default_parse) do
            {:ok, parse} ->
              quote(do: fn params -> unquote(parse).(params, unquote(field_name)) end)

            :error ->
              quote(do: &Map.fetch(&1, unquote(to_string(field_name))))
          end
      end

    parse_field =
      case Keyword.fetch!(params, :default) do
        {:ok, value} ->
          quote do
            fn params ->
              with :error <- unquote(parse).(params), do: {:ok, unquote(value)}
            end
          end

        :error ->
          result_wrap(
            parse,
            {quote(do: {:ok, value}), quote(do: {:ok, value})},
            {:error, :parse_error}
          )
      end

    Keyword.put(params, :parse, parse_field)
  end

  defp result_wrap(function, {success_match, success_return}, {error_match, error_type}) do
    quote do
      fn value ->
        case unquote(function).(value) do
          unquote(success_match) ->
            unquote(success_return)

          unquote(error_match) ->
            {:error, %ErrorContext{error_type: unquote(error_type), problem_value: value}}

          {:error, %ErrorContext{} = context} ->
            {:error, context}
        end
      end
    end
  end
end
