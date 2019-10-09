defmodule Breakfast do
  alias Breakfast.Digest.{Data, Field}
  alias Breakfast.{Error, Type}

  @type quoted :: term()

  defmacro __using__(_) do
    quote do
      import Breakfast, only: [defdata: 2]
    end
  end

  defmacro defdata(name, do: block) do
    name
    |> Breakfast.Digest.digest_data(block)
    |> define_module()
  end

  @spec define_module(Data.t()) :: quoted()
  defp define_module(data) do
    quote do
      defmodule unquote(data.name) do
        unquote_splicing(Enum.map(data.datas, &define_module/1))

        unquote(define_type(data))

        unquote(build_struct(data))

        unquote(define_validators(data))
      end
    end
  end

  @spec define_validators(Data.t()) :: quoted()
  defp define_validators(data) do
    quote do
      def decode(%{} = params) do
        Enum.reduce_while(@all_keys, [], fn field_name, validated_fields ->
          case decode_field(field_name, params) do
            {:ok, field_value} ->
              {:cont, [{field_name, field_value} | validated_fields]}

            {:error, error} ->
              {:halt, {:error, error}}
          end
        end)
        |> case do
          validated_params when is_list(validated_params) ->
            {:ok, struct!(__MODULE__, validated_params)}

          {:error, error} ->
            {:error, error}
        end
      end

      unquote(define_field_validators(data))
    end
  end

  @spec define_field_validators(Data.t()) :: quoted()
  defp define_field_validators(data) do
    quote do
      (unquote_splicing(Enum.map(data.fields, &define_field_validator/1)))
    end
  end

  @spec define_field_validator(Field.t()) :: quoted()
  defp define_field_validator(field) do
    quote do
      defp decode_field(unquote(field.name), params) do
        with {:ok, parsed_value} <- unquote(field.parse).(params),
             {:ok, casted_value} <- cast_field(unquote(field.name), parsed_value),
             :ok <- validate_field(unquote(field.name), casted_value) do
          {:ok, casted_value}
        end
      end

      unquote(define_cast_field(field))
      unquote(define_validate_field(field))
    end
  end

  @spec define_cast_field(Field.t()) :: quoted()
  defp define_cast_field(field) do
    quote do
      defp cast_field(unquote(field.name), value) do
        case unquote(generate_field_cast(field)).(value) do
          {:ok, casted_value} ->
            {:ok, casted_value}

          :error ->
            {:error, Error.new_cast_error(unquote(field.name), value)}
        end
      end
    end
  end

  @spec define_validate_field(Field.t()) :: quoted()
  defp define_validate_field(field) do
    quote do
      defp validate_field(unquote(field.name), value) do
        case unquote(generate_field_validator(field)).(value) do
          :ok ->
            :ok

          :error ->
            {:error, Error.new_validate_error(unquote(field.name), value)}
        end
      end
    end
  end

  @spec generate_field_cast(Field.t()) :: quoted()
  defp generate_field_cast(field) do
    case Keyword.fetch(field.options, :cast) do
      {:ok, cast} ->
        quote do
          fn value ->
            case unquote(cast).(value) do
              {:ok, casted_value} ->
                {:ok, casted_value}

              :error ->
                :error

              other ->
                raise "Invalid return from cast for field"
            end
          end
        end

      :error ->
        quote(do: fn value -> {:ok, value} end)
    end
  end

  @spec generate_field_validator(Field.t()) :: quoted()
  defp generate_field_validator(field) do
    case Keyword.fetch(field.options, :validate) do
      {:ok, validate} ->
        quote do
          fn value ->
            case unquote(validate).(value) do
              :ok ->
                :ok

              :error ->
                :error

              other ->
                raise "Invalid return from validate for field"
            end
          end
        end

      :error ->
        quote do
          fn value ->
            unquote(type_derived_validator(field.type)).(value)
          end
        end
    end
  end

  @spec type_derived_validator(Type.spec()) :: quoted()
  defp type_derived_validator(type) do
    case Type.fetch_predicate(type) do
      {:ok, predicate} ->
        validator_from_predicate(predicate)

      :error ->
        raise "Cannot infer a validator for custom type: #{inspect(type)}"
    end
  end

  @spec validator_from_predicate(Type.predicate()) :: quoted()
  defp validator_from_predicate(predicate) do
    quote do
      fn value ->
        if unquote(predicate).(value) do
          :ok
        else
          :error
        end
      end
    end
  end

  @spec define_type(Data.t()) :: quoted()
  defp define_type(data) do
    quote do
      @type t :: %__MODULE__{
              unquote_splicing(field_types(data))
            }
    end
  end

  @spec field_types(Data.t()) :: quoted()
  defp field_types(data) do
    Enum.map(data.fields, fn field ->
      {field.name, field.type}
    end)
  end

  @spec build_struct(Data.t()) :: quoted()
  defp build_struct(data) do
    quote do
      @struct_fields unquote(struct_fields(data.fields))
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
