defmodule Breakfast do
  alias Breakfast.CompileError
  alias Breakfast.Digest.{Decoder, Field}

  @type quoted :: term()

  defmodule Field do
    defstruct [:mod, :name, :type, :fetcher, :caster, :validator]
  end

  defmacro __using__(_) do
    quote do
      import Breakfast, only: [cereal: 1, cereal: 2]

      Module.register_attribute(__MODULE__, :breakfast_raw_fields, accumulate: true)

      Module.register_attribute(__MODULE__, :breakfast_validators, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_casters, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_fetchers, accumulate: true)
    end
  end

  defmacro cereal(opts \\ [], do: block) do
    cereal_validator = Keyword.get(opts, :validate)
    cereal_caster = Keyword.get(opts, :cast)
    cereal_fetcher = Keyword.get(opts, :fetch)

    quote do
      default_validators = %{
        :string => &Breakfast.Validate.string/1,
        :integer => &Breakfast.Validate.integer/1,
        :float => &Breakfast.Validate.float/1
      }

      default_casters = %{
        :string => &Breakfast.Cast.string/1,
        :integer => &Breakfast.Cast.integer/1,
        :float => &Breakfast.Cast.float/1
      }

      try do
        import Breakfast, only: [field: 2, field: 3, type: 2]
        unquote(block)
      after
        :ok
      end

      raw_fields = Enum.reverse(@breakfast_raw_fields)

      custom_validators = Enum.into(@breakfast_validators, %{})
      custom_casters = Enum.into(@breakfast_casters, %{})
      custom_fetchers = Enum.into(@breakfast_fetchers, %{})

      all_validators = Map.merge(default_validators, custom_validators)
      all_casters = Map.merge(default_casters, custom_casters)

      unless unquote(cereal_caster), do: Breakfast.check_casters(raw_fields, all_casters)
      unless unquote(cereal_validator), do: Breakfast.check_validators(raw_fields, all_validators)

      @breakfast_fields Enum.map(raw_fields, fn {name, type, _opts} = raw_field ->
                          %Field{mod: __MODULE__, name: name, type: type}
                          |> Breakfast.set_fetcher(custom_fetchers, unquote(cereal_fetcher))
                          |> Breakfast.set_caster(
                            custom_casters,
                            unquote(cereal_caster),
                            default_casters
                          )
                          |> Breakfast.set_validator(
                            custom_validators,
                            unquote(cereal_validator),
                            default_validators
                          )
                        end)

      defstruct Enum.map(raw_fields, fn {name, _, _} -> name end)

      def __cereal__(:fields), do: @breakfast_fields

      @spec decode(params :: term()) :: %Breakfast.Yogurt{}
      def decode(params) do
        Enum.reduce(
          @breakfast_fields,
          %Breakfast.Yogurt{struct: %__MODULE__{}},
          fn %Breakfast.Field{
               name: name,
               type: type,
               fetcher: fetcher,
               caster: caster,
               validator: validator
             } = field,
             %Breakfast.Yogurt{errors: errors, struct: struct} = yogurt ->
            with {:fetch, {:ok, value}} <- {:fetch, Breakfast.fetch(params, field)},
                 {:cast, {:ok, cast_value}} <- {:cast, Breakfast.cast(value, field)},
                 {:validate, []} <- {:validate, Breakfast.validate(value, field)} do
              %Breakfast.Yogurt{yogurt | struct: %{struct | name => cast_value}}
            else
              {:fetch, :error} ->
                %Breakfast.Yogurt{
                  yogurt
                  | errors: [{name, "Couldn't fetch value for #{name}"} | errors]
                }

              {:cast, :error} ->
                %Breakfast.Yogurt{yogurt | errors: [{name, "Cast error for #{name}"} | errors]}

              {:validate, validation_errors} when is_list(validation_errors) ->
                %Breakfast.Yogurt{
                  yogurt
                  | errors: [Enum.map(validation_errors, &{name, &1}) | errors]
                }

              {:fetch, retval} ->
                raise "Expected #{name}.fetch (#{inspect(fetcher)}) to return an {:ok, value} tuple, got #{
                        inspect(retval)
                      }"

              {:cast, retval} ->
                raise "Expected #{name}.cast (#{inspect(caster)}) to return an {:ok, value} tuple or :error, got #{
                        inspect(retval)
                      }"

              {:validate, retval} ->
                raise "Expected #{name}.validate (#{inspect(validator)}) to return a list, got #{
                        inspect(retval)
                      }"
            end
          end
        )
      end
    end
  end

  def set_fetcher(%Field{name: name, type: type} = field, custom_fetchers, cereal_fetcher) do
    %Field{
      field
      | fetcher:
          Map.get(custom_fetchers, {name, type}) || Map.get(custom_fetchers, type) ||
            cereal_fetcher || (&Breakfast.Fetch.string/2)
    }
  end

  def set_caster(
        %Field{name: name, type: type} = field,
        custom_casters,
        cereal_caster,
        default_casters
      ) do
    %Field{
      field
      | caster:
          Map.get(custom_casters, {name, type}) || Map.get(custom_casters, type) || cereal_caster ||
            Map.get(default_casters, {name, type}) || Map.get(default_casters, type)
    }
  end

  def set_validator(
        %Field{name: name, type: type} = field,
        custom_validators,
        cereal_validator,
        default_validators
      ) do
    %Field{
      field
      | validator:
          Map.get(custom_validators, {name, type}) || Map.get(custom_validators, type) ||
            cereal_validator || Map.get(default_validators, {name, type}) ||
            Map.get(default_validators, type)
    }
  end

  defmodule Yogurt do
    defstruct params: nil, errors: [], struct: nil

    def valid?(%__MODULE__{errors: []}), do: true
    def valid?(%__MODULE__{errors: [_ | _]}), do: false
  end

  def fetch(params, %Field{mod: mod, name: name, fetcher: fetcher}),
    do: apply_fn(mod, fetcher, [params, name])

  def cast(value, %Field{mod: mod, caster: caster}), do: apply_fn(mod, caster, [value])

  def validate(value, %Field{mod: mod, validator: validator}),
    do: apply_fn(mod, validator, [value])

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

  def check_validators(fields, validators) do
    Enum.each(fields, fn {name, type, opts} ->
      with false <- Keyword.has_key?(opts, :validate),
           false <- Map.has_key?(validators, type) do
        raise "%CompileError{}: No validator for :#{name}"
      end
    end)
  end

  def check_casters(fields, casters) do
    Enum.each(fields, fn {name, type, opts} ->
      with false <- Keyword.has_key?(opts, :cast),
           false <- Map.has_key?(casters, type) do
        raise "%CompileError{}: No cast for :#{name}"
      end
    end)
  end

  defmacro field(name, spec, opts \\ []) do
    type = type_from_spec(spec)

    quote bind_quoted: [name: name, type: type, opts: opts] do
      validate = Keyword.get(opts, :validate)
      cast = Keyword.get(opts, :cast)
      fetch = Keyword.get(opts, :fetch)

      Module.put_attribute(__MODULE__, :breakfast_raw_fields, {name, type, opts})

      if validate,
        do: Module.put_attribute(__MODULE__, :breakfast_validators, {{name, type}, validate})

      if cast, do: Module.put_attribute(__MODULE__, :breakfast_casters, {{name, type}, cast})
      if fetch, do: Module.put_attribute(__MODULE__, :breakfast_fetchers, {{name, type}, fetch})
    end
  end

  defmacro type(spec, opts) do
    type = type_from_spec(spec)

    quote bind_quoted: [type: type, opts: opts] do
      validate = Keyword.get(opts, :validate)
      cast = Keyword.get(opts, :cast)
      fetch = Keyword.get(opts, :fetch)

      unless validate || cast || fetch, do: raise("add :cast, :validate or :fetch to type/2")

      if validate, do: Module.put_attribute(__MODULE__, :breakfast_validators, {type, validate})
      if cast, do: Module.put_attribute(__MODULE__, :breakfast_casters, {type, cast})
      if fetch, do: Module.put_attribute(__MODULE__, :breakfast_fetchers, {type, fetch})
    end
  end

  defp type_from_spec({{:., _, [{:__aliases__, _, [:String]}, :t]}, _, []}), do: :string
  defp type_from_spec({:integer, _, []}), do: :integer
  defp type_from_spec({:float, _, []}), do: :float
  defp type_from_spec({:number, _, []}), do: :number
  defp type_from_spec({:map, _, []}), do: :map

  defp type_from_spec({{:., _, [{:__aliases__, _, alias_}, type]}, _, _type_params}),
    do: {:custom, {alias_, type}}

  defp type_from_spec({type, _, _}), do: {:custom, type}

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
      @spec decode_field(field_name :: atom(), params :: term()) ::
              {:ok, term()} | {:error, ErrorContext.t()}
      defp decode_field(unquote(field.name), params) do
        with {:ok, parsed_value} <- unquote(field.parse).(params),
             {:ok, casted_value} <- unquote(field.cast).(parsed_value),
             :ok <- unquote(field.validate).(casted_value) do
          {:ok, casted_value}
        end
      end
    end
  end

  #  @spec define_type(Decoder.t()) :: quoted()
  #  defp define_type(decoder) do
  #    quote do
  #      @type t :: %__MODULE__{
  #              unquote_splicing(field_types(decoder))
  #            }
  #    end
  #  end

  #  @spec field_types(Decoder.t()) :: quoted()
  #  defp field_types(decoder), do: for(field <- decoder.fields, do: {field.name, field.type})

  #  @spec build_struct(Decoder.t()) :: quoted()
  #  defp build_struct(decoder) do
  #    quote do
  #      @struct_fields unquote(struct_fields(decoder.fields))
  #      @enforce_keys Enum.reject(@struct_fields, &match?({_, _}, &1))
  #      @all_keys Enum.map(@struct_fields, &with({key, _} <- &1, do: key))
  #      defstruct @struct_fields
  #    end
  #  end
  #
  #  @spec struct_fields([Field.t()]) :: [atom() | {atom(), term()}]
  #  defp struct_fields(fields) do
  #    Enum.reduce(fields, [], fn %Field{name: name, options: options}, acc ->
  #      case Keyword.fetch(options, :default) do
  #        {:ok, default_value} ->
  #          [{name, default_value} | acc]
  #
  #        :error ->
  #          [name | acc]
  #      end
  #    end)
  #  end

  @spec decode(mod :: module(), params :: term()) :: %Yogurt{}
  def decode(mod, params) do
    Enum.reduce(
      mod.__cereal__(:fields),
      %Yogurt{struct: struct(mod)},
      fn %Field{
           name: name,
           type: type,
           fetcher: fetcher,
           caster: caster,
           validator: validator
         } = field,
         %Yogurt{errors: errors, struct: struct} = yogurt ->
        with {:fetch, {:ok, value}} <- {:fetch, fetch(params, field)},
             {:cast, {:ok, cast_value}} <- {:cast, cast(value, field)},
             {:validate, []} <- {:validate, validate(cast_value, field)} do
          %Yogurt{yogurt | struct: %{struct | name => cast_value}}
        else
          {:fetch, :error} ->
            %Yogurt{
              yogurt
              | errors: [{name, "Couldn't fetch value for #{name}"} | errors]
            }

          {:cast, :error} ->
            %Yogurt{yogurt | errors: [{name, "Cast error for #{name}"} | errors]}

          {:validate, validation_errors} when is_list(validation_errors) ->
            %Yogurt{
              yogurt
              | errors: [Enum.map(validation_errors, &{name, &1}) | errors]
            }

          {:fetch, retval} ->
            raise "Expected #{name}.fetch (#{inspect(fetcher)}) to return an {:ok, value} tuple, got #{
                    inspect(retval)
                  }"

          {:cast, retval} ->
            raise "Expected #{name}.cast (#{inspect(caster)}) to return an {:ok, value} tuple or :error, got #{
                    inspect(retval)
                  }"

          {:validate, retval} ->
            raise "Expected #{name}.validate (#{inspect(validator)}) to return a list, got #{
                    inspect(retval)
                  }"
        end
      end
    )
  end

  @spec unwrap(%Yogurt{}) :: %Yogurt{} | struct()
  def unwrap(%Yogurt{errors: [], struct: struct}), do: struct
  def unwrap(%Yogurt{errors: errors} = yogurt) when is_list(errors), do: yogurt
end
