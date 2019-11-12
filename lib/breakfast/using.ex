defmodule Breakfast.Using do
  @moduledoc false
  alias Breakfast.{Field, Type}

  defmacro __using__([]) do
    quote do
      import Breakfast.Using, only: [cereal: 1, cereal: 2]

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
        import Breakfast.Using, only: [field: 2, field: 3, type: 2]
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
                          |> Breakfast.Using.set_fetcher(custom_fetchers, unquote(cereal_fetcher))
                          |> Breakfast.Using.set_caster(custom_casters, unquote(cereal_caster))
                          |> Breakfast.Using.set_validator(
                            custom_validators,
                            unquote(cereal_validator)
                          )
                          |> Breakfast.Using.set_default_value(
                            custom_default_values,
                            unquote(cereal_default_value)
                          )
                        end)

      if unquote(generate_type?),
        do: Breakfast.Using.__define_type_spec__(@breakfast_field_type_specs)

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

  @spec set_default_value(Field.t(), map(), Breakfast.result(term())) :: Field.t()
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
end
