defmodule Breakfast do
  alias Breakfast.Digest.{Data, Field}

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
             {:ok, casted_value} <- unquote(field.cast).(parsed_value),
             :ok <- unquote(field.validate).(casted_value) do
          {:ok, casted_value}
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
  defp field_types(data), do: for field <- data.fields, do: {field.name, field.type}

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
