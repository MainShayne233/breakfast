defmodule Breakfast.Digest do
  defmodule Field do
    alias Breakfast.Type

    @type parse :: (term() -> {:ok, term()} | :error)

    @type t :: %__MODULE__{
            name: atom(),
            type: Type.spec(),
            default: {:ok, term()} | :error,
            parse: parse(),
            options: Keyword.t()
          }

    @enforce_keys [:name, :type, :default, :parse, :options]
    defstruct @enforce_keys
  end

  defmodule Data do
    @type t :: %__MODULE__{
            name: term(),
            fields: [Field.t()],
            datas: [t()]
          }

    @enforce_keys [:name]
    @keys_with_defaults [fields: [], datas: []]

    defstruct @enforce_keys ++ @keys_with_defaults
  end

  alias Breakfast.Error

  @type block :: {:__block__, term(), list()}

  @doc """
  Handles parsing the definition and defining a single Data.t() to describe it.
  """
  @spec digest_data(name :: term(), block() | term()) :: Data.t()
  def digest_data(name, {:__block__, _, expressions}) do
    Enum.reduce(expressions, %Data{name: name}, fn
      {:field, _, params}, data ->
        %Data{data | fields: [digest_field(params) | data.fields]}

      {:defdata, _, [name, [do: block]]}, data ->
        %Data{data | datas: [digest_data(name, block) | data.datas]}
    end)
  end

  def digest_data(name, expr) do
    digest_data(name, {:__block__, [], [expr]})
  end

  @spec digest_field(list()) :: Field.t()
  defp digest_field([name, type | rest]) do
    options = Enum.at(rest, 0, [])

    params =
      [name: name, type: type]
      |> digest_default(options)
      |> digest_parse(options)
      |> Keyword.put(:options, options)

    struct!(Field, params)
  end

  defp digest_default(params, options) do
    default = Keyword.fetch(options, :default)
    Keyword.put(params, :default, default)
  end

  defp digest_parse(params, options) do
    field_name = Keyword.fetch!(params, :name)

    parse =
      case Keyword.fetch(options, :parse) do
        {:ok, parse} ->
          parse

        :error ->
          quote(do: &Map.fetch(&1, unquote(to_string(field_name))))
      end

    parse_field =
      quote do
        fn params ->
          case unquote(parse).(params) do
            {:ok, value} ->
              {:ok, value}

            :error ->
              unquote(
                case Keyword.fetch!(params, :default) do
                  {:ok, default_value} ->
                    {:ok, default_value}

                  :error ->
                    {:error, Macro.escape(Error.new_parse_error(field_name))}
                end
              )

            other ->
              raise "Bad return from parse from field: #{unquote(field_name)}. Expected {:ok, term()} | :error, got: #{
                      inspect(other)
                    }"
          end
        end
      end

    Keyword.put(params, :parse, parse_field)
  end
end
