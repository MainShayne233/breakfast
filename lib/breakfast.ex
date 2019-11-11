defmodule Breakfast do
  alias Breakfast.{Type, Yogurt}

  defmodule Field do
    use TypedStruct

    @type type :: atom() | {:cereal, module()}

    typedstruct do
      field :mod, atom()
      field :name, atom()
      field :type, type()
      field :fetcher, atom()
      field :caster, atom()
      field :validator, atom()
      field :default, atom()
    end
  end

  @type result(t) :: {:ok, t} | :error

  @spec __using__([]) :: Macro.t()
  defmacro __using__([]) do
    quote do
      import Breakfast, only: [cereal: 1, cereal: 2]

      Module.register_attribute(__MODULE__, :breakfast_raw_fields, accumulate: true)

      Module.register_attribute(__MODULE__, :breakfast_validators, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_casters, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_fetchers, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_default_values, accumulate: true)
      Module.register_attribute(__MODULE__, :breakfast_field_type_specs, accumulate: true)
    end
  end

  @spec cereal(keyword(), Macro.t()) :: Macro.t()
  defmacro cereal(opts \\ [], expr)

  defmacro cereal(opts, do: block) when is_list(opts) do
    cereal_validator = Keyword.get(opts, :validate)
    cereal_caster = Keyword.get(opts, :cast)
    cereal_fetcher = Keyword.get(opts, :fetch)
    cereal_default_value = Keyword.fetch(opts, :default)
    generate_type? = Keyword.get(opts, :generate_type, true)

    quote do
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
      custom_default_values = Enum.into(@breakfast_default_values, %{})

      @breakfast_fields Enum.map(raw_fields, fn {name, type, _opts} = raw_field ->
                          %Field{mod: __MODULE__, name: name, type: type}
                          |> Breakfast.set_fetcher(custom_fetchers, unquote(cereal_fetcher))
                          |> Breakfast.set_caster(custom_casters, unquote(cereal_caster))
                          |> Breakfast.set_validator(custom_validators, unquote(cereal_validator))
                          |> Breakfast.set_default_value(
                            custom_default_values,
                            unquote(cereal_default_value)
                          )
                        end)

      if unquote(generate_type?), do: Breakfast.__define_type_spec__(@breakfast_field_type_specs)

      defstruct Enum.map(raw_fields, fn {name, _, _} -> name end)

      def __cereal__(:fields), do: @breakfast_fields
    end
  end

  defmacro cereal(_bad_opts, _bad_expr) do
    raise "Invalid cereal definition"
  end

  @spec __define_type_spec__([Macro.t()]) :: Macro.t()
  defmacro __define_type_spec__(type_specs) do
    quote bind_quoted: [type_specs: type_specs] do
      @type breakfast_t :: %__MODULE__{
              unquote_splicing(type_specs)
            }
    end
  end

  @spec set_fetcher(Field.t(), map(), atom() | nil) :: Field.t()
  def set_fetcher(%Field{name: name, type: type} = field, custom_fetchers, cereal_fetcher) do
    %Field{
      field
      | fetcher:
          Map.get(custom_fetchers, {name, type}) || Map.get(custom_fetchers, type) ||
            cereal_fetcher || :default
    }
  end

  @spec set_caster(Field.t(), map(), atom() | nil) :: Field.t()
  def set_caster(%Field{name: name, type: type} = field, custom_casters, cereal_caster) do
    %Field{
      field
      | caster:
          Map.get(custom_casters, {name, type}) || Map.get(custom_casters, type) || cereal_caster ||
            :default
    }
  end

  @spec set_validator(Field.t(), map(), atom() | nil) :: Field.t()
  def set_validator(%Field{name: name, type: type} = field, custom_validators, cereal_validator) do
    %Field{
      field
      | validator:
          Map.get(custom_validators, {name, type}) || Map.get(custom_validators, type) ||
            cereal_validator || :default
    }
  end

  @spec set_default_value(Field.t(), map(), result(term())) :: Field.t()
  def set_default_value(
        %Field{name: name, type: type} = field,
        custom_default_values,
        cereal_default_value
      ) do
    default_value =
      with :error <- Map.fetch(custom_default_values, {name, type}),
           :error <- Map.fetch(custom_default_values, type),
           :error <- cereal_default_value do
        :error
      end

    %Field{field | default: default_value}
  end

  @spec fetch(term(), Field.t()) :: result(term())
  def fetch(params, field) do
    with :error <- do_fetch(params, field), do: field.default
  end

  @spec do_fetch(term(), Field.t()) :: result(term())
  defp do_fetch(params, %Field{name: name, fetcher: :default}),
    do: Map.fetch(params, to_string(name))

  defp do_fetch(params, %Field{mod: mod, name: name, fetcher: fetcher}),
    do: apply_fn(mod, fetcher, [params, name])

  @spec cast(term(), Field.t()) :: result(term())
  def cast(value, %Field{caster: :default, type: {:cereal, module}}) do
    case Breakfast.decode(module, value) do
      %Breakfast.Yogurt{errors: [], struct: struct} ->
        {:ok, struct}

      %Breakfast.Yogurt{errors: [_ | _]} = yogurt ->
        {:ok, yogurt}
    end
  end

  def cast(value, %Field{caster: :default}), do: {:ok, value}

  def cast(value, %Field{mod: mod, caster: caster}), do: apply_fn(mod, caster, [value])

  @spec validate(term(), Field.t()) :: [String.t()]
  def validate(value, %Field{validator: :default, type: {:cereal, module}}) do
    case value do
      %^module{} ->
        []

      %Breakfast.Yogurt{errors: errors} ->
        [errors]
    end
  end

  def validate(value, %Field{validator: :default, type: type}),
    do: Breakfast.Type.validate(type, value)

  def validate(value, %Field{mod: mod, validator: validator}),
    do: apply_fn(mod, validator, [value])

  @spec apply_fn(module(), fun() | {atom(), keyword()} | atom(), [term()]) :: term()
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

  @spec field(atom(), Macro.t(), keyword()) :: Macro.t()
  defmacro field(name, spec, opts \\ []) do
    type = Type.derive_from_spec(spec)

    quote do
      Module.put_attribute(
        __MODULE__,
        :breakfast_raw_fields,
        {unquote(name), unquote(type), unquote(opts)}
      )

      Module.put_attribute(
        __MODULE__,
        :breakfast_field_type_specs,
        {unquote(name), unquote(Macro.escape(spec))}
      )

      [
        {:validate, :breakfast_validators},
        {:cast, :breakfast_casters},
        {:fetch, :breakfast_fetchers},
        {:default, :breakfast_default_values}
      ]
      |> Enum.each(fn {key, attr} ->
        with {:ok, value} <- Keyword.fetch(unquote(opts), key) do
          Module.put_attribute(__MODULE__, attr, {{unquote(name), unquote(type)}, value})
        end
      end)
    end
  end

  @spec type(Macro.t(), keyword()) :: Macro.t()
  defmacro type(spec, opts) do
    type = Type.derive_from_spec(spec)

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

  @spec decode(mod :: module(), params :: term()) :: Yogurt.t()
  def decode(mod, params) do
    Enum.reduce(
      mod.__cereal__(:fields),
      %Yogurt{struct: struct(mod), params: params},
      fn %Field{
           name: name,
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
            %Yogurt{yogurt | errors: [{name, "value not found"} | errors]}

          {:cast, :error} ->
            %Yogurt{yogurt | errors: [{name, "cast error"} | errors]}

          {:validate, validation_errors} when is_list(validation_errors) ->
            %Yogurt{yogurt | errors: Enum.map(validation_errors, &{name, &1}) ++ errors}

          {:fetch, retval} ->
            raise "Expected #{name}.fetch (#{inspect(fetcher)}) to return an {:ok, value} tuple, got #{
                    inspect(retval)
                  }"

          {:cast, retval} ->
            raise "Expected #{name}.cast (#{inspect(caster)}) to return an {:ok, value} tuple or :error, got #{
                    inspect(retval)
                  }"

          {:validate, retval} ->
            raise "Expected #{name}.validate (#{inspect(validator)}) to return a list, got: #{
                    inspect(retval)
                  }"
        end
      end
    )
  end

  @spec unwrap(Yogurt.t()) :: Yogurt.t() | struct()
  def unwrap(%Yogurt{errors: [], struct: struct}), do: struct
  def unwrap(%Yogurt{errors: errors} = yogurt) when is_list(errors), do: yogurt
end
