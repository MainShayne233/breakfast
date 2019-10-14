defmodule Breakfast do
  alias Breakfast.CompileError
  alias Breakfast.Digest.{Decoder, Field}

  @type quoted :: term()

  defmacro __using__(_) do
    quote do
      import Breakfast, only: [defdecoder: 2, defdecoder: 3]
    end
  end

  defmacro defdecoder(name, options, do: block) do
    do_defdecoder(name, options, block)
  end

  defmacro defdecoder(name, do: block) do
    do_defdecoder(name, [], block)
  end

  @spec do_defdecoder(module_name :: quoted(), options :: Keyword.t(), block :: quoted()) ::
          quoted() | no_return()
  defp do_defdecoder(name, options, block) do
    name
    |> Breakfast.Digest.digest_decoder(block, options)
    |> define_module()
  rescue
    error in CompileError ->
      raise CompileError.new_module_define_error(name, error)
  end

  @spec define_module(Decoder.t()) :: quoted()
  defp define_module(decoder) do
    quote do
      defmodule unquote(decoder.name) do
        alias Breakfast.{DecodeError, ErrorContext}

        unquote_splicing(Enum.map(decoder.decoders, &define_module/1))

        unquote(define_type(decoder))

        unquote(build_struct(decoder))

        unquote(define_validators(decoder))
      end
    end
  end

  @non_raise_error_types [:parse_error, :validate_error, :cast_error]

  @spec define_validators(Decoder.t()) :: quoted()
  defp define_validators(decoder) do
    quote do
      @spec decode(params :: term()) :: {:ok, t()} | {:error, DecodeError.t()}
      def decode(params) do
        with {:error, %ErrorContext{} = context} <- __decode__(params) do
          case DecodeError.from_context(context, params) do
            %DecodeError{type: error_type} = error
            when error_type in unquote(@non_raise_error_types) ->
              {:error, error}

            %DecodeError{} = error_to_raise ->
              raise error_to_raise
          end
        end
      end

      @spec __decode__(params :: term()) :: {:ok, t()} | {:error, ErrorContext.t()}
      def __decode__(params) do
        Enum.reduce_while(@all_keys, [], fn field_name, validated_fields ->
          case decode_field(field_name, params) do
            {:ok, field_value} ->
              {:cont, [{field_name, field_value} | validated_fields]}

            {:error, %ErrorContext{} = error_context} ->
              {:halt, {:error, ErrorContext.prepend_field(error_context, field_name)}}
          end
        end)
        |> case do
          validated_params when is_list(validated_params) ->
            {:ok, struct!(__MODULE__, validated_params)}

          {:error, error} ->
            {:error, error}
        end
      end

      unquote(define_field_validators(decoder))
    end
  end

  @spec define_field_validators(Decoder.t()) :: quoted()
  defp define_field_validators(decoder) do
    quote do
      (unquote_splicing(Enum.map(decoder.fields, &define_field_validator/1)))
    end
  end

  @spec define_field_validator(Field.t()) :: quoted()
  defp define_field_validator(field) do
    quote do
      @spec decode_field(field_name :: atom(), params :: term()) :: {:ok, term()} | {:error, ErrorContext.t()}
      defp decode_field(unquote(field.name), params) do
        with {:ok, parsed_value} <- unquote(field.parse).(params),
             {:ok, casted_value} <- unquote(field.cast).(parsed_value),
             :ok <- unquote(field.validate).(casted_value) do
          {:ok, casted_value}
        end
      end
    end
  end

  @spec define_type(Decoder.t()) :: quoted()
  defp define_type(decoder) do
    quote do
      @type t :: %__MODULE__{
              unquote_splicing(field_types(decoder))
            }
    end
  end

  @spec field_types(Decoder.t()) :: quoted()
  defp field_types(decoder), do: for(field <- decoder.fields, do: {field.name, field.type})

  @spec build_struct(Decoder.t()) :: quoted()
  defp build_struct(decoder) do
    quote do
      @struct_fields unquote(struct_fields(decoder.fields))
      @enforce_keys Enum.reject(@struct_fields, &match?({_, _}, &1))
      @all_keys Enum.map(@struct_fields, &with({key, _} <- &1, do: key))
      defstruct @struct_fields
    end
  end

  @spec struct_fields([Field.t()]) :: [atom() | {atom(), term()}]
  defp struct_fields(fields) do
    Enum.reduce(fields, [], fn %Field{name: name, options: options}, acc ->
      case Keyword.fetch(options, :default) do
        {:ok, default_value} ->
          [{name, default_value} | acc]

        :error ->
          [name | acc]
      end
    end)
  end
end
