defmodule Breakfast.Digest do
  defmodule Field do
    alias Breakfast.Types

    @type t :: %__MODULE__{
            name: atom(),
            type: Types.valid_type_def(),
            options: Keyword.t()
          }

    @enforce_keys [:name, :type, :options]
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
    %Field{name: name, type: type, options: Enum.at(rest, 0, [])}
  end
end
