defmodule Vlad do
  defmacro __using__(_) do
    quote do
      import Customs, only: [decoder: 2]
    end
  end

  defmacro decoder(name, do: {:__block__, _, body}) do
    quote do
      defmodule unquote(name) do
        defmodule TypeError do
          defexception message: "Invalid type for field",
                       field: nil,
                       expected_type: nil,
                       value: nil
        end

        defmodule InvalidFieldError do
          defexception message: "Invalid field provided", field: nil, value: nil
        end

        defmodule MissingFieldsError do
          defexception message: "Missing fields", missing_fields: []
        end

        import Customs, only: [decoder: 2]

        @fields unquote(struct_fields(body))

        @enforce_keys Enum.reject(@fields, &match?({_, _}, &1))

        unquote(typespec(body))

        defstruct @fields

        unquote_splicing(nested_decoders(body))

        unquote(validate_function())

        unquote_splicing(field_validators(body))

        defp validate_field(field_name, value) do
          {:error, %InvalidFieldError{field: field_name, value: value}}
        end
      end
    end
  end

  def validate_value(:string, value, _options) when is_binary(value), do: {:ok, value}
  def validate_value(:float, value, _options) when is_float(value), do: {:ok, value}
  def validate_value(:boolean, value, _options) when is_boolean(value), do: {:ok, value}

  def validate_value(module, %{} = value, _options) when is_atom(module) do
    module.validate(value)
  end

  def validate_value(_type, _value, _options) do
    :error
  end

  defp validate_function do
    quote do
      def validate(params) do
        validated_params =
          Enum.reduce_while(params, %{}, fn {key, value}, acc ->
            case validate_field(key, value) do
              {:ok, {field_name, value}} ->
                {:cont, Map.put(acc, field_name, value)}

              {:error, error} ->
                {:halt, {:error, error}}
            end
          end)

        with %{} <- validated_params,
             :ok <- validate_required_fields(validated_params) do
          {:ok, struct!(__MODULE__, validated_params)}
        end
      end

      defp validate_required_fields(validated_params) do
        case @enforce_keys -- Map.keys(validated_params) do
          [] ->
            :ok

          missing_fields ->
            {:error, %MissingFieldsError{missing_fields: Enum.map(missing_fields, &to_string/1)}}
        end
      end
    end
  end

  defp typespec(body) do
    quote do
      @type t :: %__MODULE__{
              unquote_splicing(typespec_fields(body))
            }
    end
  end

  defp field_validators(body) do
    Enum.reduce(body, [], fn
      {:field, _, field}, acc ->
        [field_validator(field) | acc]

      _other, acc ->
        acc
    end)
  end

  defp field_validator([field_name, type]) do
    field_validator([field_name, type, []])
  end

  defp field_validator([field_name, type, options]) do
    quote do
      defp validate_field(unquote(to_string(field_name)), value) do
        case Customs.validate_value(unquote(type), value, unquote(options)) do
          {:ok, validated_value} ->
            {:ok, {unquote(field_name), validated_value}}

          :error ->
            {:error,
             %TypeError{
               field: unquote(to_string(field_name)),
               expected_type: unquote(type),
               value: value
             }}

          {:error, error} ->
            {:error, error}
        end
      end
    end
  end

  defp typespec_fields(body) do
    Enum.reduce(body, [], fn
      {:field, _, [field_name, type | _]}, acc ->
        [{field_name, spec(type)} | acc]

      _other, acc ->
        acc
    end)
  end

  defp spec(:string) do
    quote do
      String.t()
    end
  end

  defp spec(:float) do
    quote do
      float()
    end
  end

  defp spec(:boolean) do
    quote do
      boolean()
    end
  end

  defp spec({:__aliases__, _, _module} = module) do
    quote do
      unquote(module).t()
    end
  end

  defp nested_decoders(body) do
    Enum.reduce(body, [], fn
      {:decoder, _, _} = decoder, acc ->
        [decoder | acc]

      _other, acc ->
        acc
    end)
  end

  defp struct_fields(body) do
    Enum.reduce(body, [], fn
      {:field, _, args}, acc ->
        [struct_field(args) | acc]

      _other, acc ->
        acc
    end)
  end

  defp struct_field([field_name, _type]), do: field_name

  defp struct_field([field_name, _type, options]) do
    case Keyword.fetch(options, :default) do
      {:ok, default_value} ->
        {field_name, default_value}

      :error ->
        field_name
    end
  end
end
