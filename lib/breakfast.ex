defmodule Breakfast do
  alias Breakfast.CompileError
  alias Breakfast.Digest.{Decoder, Field}

  @type quoted :: term()

  defmacro __using__(_) do
    quote do
      import Breakfast, only: [cereal: 1, cereal: 2]

      Module.register_attribute(__MODULE__, :breakfast_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_validates, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_casts, accumulate: true)
    end
  end

  defmacro cereal(options \\ [], do: block) do
    quote do
      default_validates = %{
        {{:., [], [{:__aliases__, [], [:String]}, :t]}, [], []} => fn _ -> true end,
        {:integer, [], []} => &is_integer/1,
        {:float, [], []} => &is_float/1,
      }

      default_casts = %{
        {{:., [], [{:__aliases__, [], [:String]}, :t]}, [], []} => fn term -> term end,# &Function.identity/1,
        {:integer, [], []} => &Breakfast.Cast.integer/1,
        {:float, [], []} => &Breakfast.Cast.float/1,
      }

      try do
        import Breakfast, only: [field: 2, field: 3, validate: 2, validate: 3, cast: 2, cast: 3]
        unquote(block)
      after
        :ok
      end

      fields = Enum.reverse(@breakfast_fields)

      validates = Enum.into(@breakfast_validates, default_validates, fn {type, validator, opts} -> {type, {validator, opts}} end)
      casts = Enum.into(@breakfast_casts, default_casts, fn {type, cast, opts} -> {type, {cast, opts}} end)

      Breakfast.check_validates(fields, validates)
      Breakfast.check_cast(fields, casts)

      defstruct Enum.map(fields, fn {name, _, _} -> name end)
    end
  end

  def check_validates(fields, validates) do
    Enum.each(fields, fn {name, type, opts} ->
      with false <- Keyword.has_key?(opts, :validate),
           false <- Map.has_key?(validates, type) do
        raise "%CompileError{}: No validator for #{name} (#{Macro.to_string(type)})"
      end
    end)
  end

  def check_cast(fields, casts) do
    Enum.each(fields, fn {name, type, opts} ->
      with false <- Keyword.has_key?(opts, :cast),
           false <- Map.has_key?(casts, type) do
        raise "%CompileError{}: No cast for #{name} (#{Macro.to_string(type)})"
      end
    end)
  end


  defmacro field(name, typespec, opts \\ []) do
    type = Macro.escape(typespec, prune_metadata: true)

    quote do
      Module.put_attribute(__MODULE__, :breakfast_fields, {unquote(name), unquote(type), unquote(opts)})
    end
  end

  defmacro validate(typespec, validator, opts \\ []) do
    type = Macro.escape(typespec, prune_metadata: true)

    quote do
      Module.put_attribute(__MODULE__, :breakfast_validates, {unquote(type), unquote(validator), unquote(opts)})
    end
  end

  defmacro cast(typespec, cast, opts \\ []) do
    type = Macro.escape(typespec, prune_metadata: true)

    quote do
      Module.put_attribute(__MODULE__, :breakfast_casts, {unquote(type), unquote(cast), unquote(opts)})
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
