defmodule Vlad do
  alias Vlad.Digest.{Data, Field}
  alias Vlad.Type
  alias Vlad.Types

  @type quoted :: term()

  import Types, only: [is_standard_type: 1]

  defmacro __using__(_) do
    quote do
      import Vlad, only: [defdata: 2]
    end
  end

  defmacro defdata(name, do: block) do
    name
    |> Vlad.Digest.digest_data(block)
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
      def validate(%{} = params) do
        Enum.reduce_while(params, [], fn {key, value}, validated_params ->
          case validate_field(key, value) do
            {:ok, {field_name, field_value}} ->
              {:cont, [{field_name, field_value} | validated_params]}

            {:error, error} ->
              {:halt, {:error, error}}
          end
        end)
        |> case do
          validated_params when is_list(validated_params) ->
            case @enforce_keys -- Keyword.keys(validated_params) do
              [] ->
                {:ok, struct!(__MODULE__, validated_params)}

              missing_fields ->
                {:error, Vlad.Error.new_missing_fields_error(missing_fields)}
            end

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
      unquote_splicing(Enum.map(data.fields, &define_field_validator/1))

      defp validate_field(invalid_key, value) do
        {:error, Vlad.Error.new_extraneous_field_error(invalid_key)}
      end
    end
  end

  @spec define_field_validator(Field.t()) :: quoted()
  defp define_field_validator(field) do
    quote do
      defp validate_field(unquote(to_string(field.name)), value) do
        with {:cast, {:ok, casted_value}} <- {:cast, unquote(generate_field_cast(field)).(value)},
             {:validate, :ok} <-
               {:validate, unquote(generate_field_validator(field)).(casted_value)} do
          {:ok, {unquote(field.name), casted_value}}
        else
          {:cast, :error} ->
            {:error, Vlad.Error.new_cast_failure_error(unquote(field.name), value)}

          {:validate, :error} ->
            {:error, Vlad.Error.new_invalid_value_error(unquote(field.name), value)}
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
        quote(do: fn _ -> {:ok, value} end)
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

  @spec type_derived_validator(Types.valid_type_def()) :: quoted()
  defp type_derived_validator(type) when is_standard_type(type) do
    Types.get_standard_type!(type).predicate
    |> validator_from_predicate()
  end

  defp type_derived_validator({:array, type}) do
    quote do
      &Enum.all?(&1, unquote(type_derived_validator(type)))
    end
  end

  defp type_derived_validator({:__aliases__, _, [_]} = module) do
    quote do
      fn value ->
        unquote(module).validate(value)
      end
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
      {field.name, field_spec(field)}
    end)
  end

  @spec build_struct(Data.t()) :: quoted()
  defp build_struct(data) do
    quote do
      @struct_fields unquote(struct_fields(data.fields))
      @enforce_keys Enum.reject(@struct_fields, &match?({_, _}, &1))
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

  @spec field_spec(Field.t()) :: quoted() | no_return()
  defp field_spec(%Field{type: field_type} = field) do
    with {:ok, default_value} <- Keyword.fetch(field.options, :default),
         {:default_type, nil} <-
           {:default_type, determine_default_type(field_type, default_value)} do
      quote do
        unquote(spec(field_type)) | nil
      end
    else
      result when result == :error or result == {:default_type, field_type} ->
        quote do
          unquote(spec(field_type))
        end

      {:default_type, _other_type} ->
        raise "Field's primary and default type differ #{inspect(field: field)}"
    end
  end

  @spec determine_default_type(Types.valid_type_def(), term()) :: Types.valid_type_def()
  defp determine_default_type(:number, value) when is_number(value), do: :number

  defp determine_default_type({:array, type}, []), do: {:array, type}

  defp determine_default_type(_field_type, value) do
    determine_type_of_value(value)
  end

  @spec determine_type_of_value(term()) :: Types.valid_type_def()
  defp determine_type_of_value(value) do
    Enum.find_value(Types.standard_types(), :error, fn %Type{name: name, predicate: predicate} ->
      if predicate.(value), do: {:ok, name}, else: false
    end)
    |> case do
      {:ok, value} ->
        value

      :error ->
        raise "Cannot determine type of value"
    end
  end

  @spec spec(Types.valid_type_def()) :: quoted()
  defp spec(type) when is_standard_type(type) do
    Types.get_standard_type!(type).spec
  end

  defp spec({:array, type}) do
    quote do
      [unquote(spec(type))]
    end
  end

  defp spec({:__aliases__, _, _module} = module) do
    quote do
      unquote(module).t()
    end
  end
end
