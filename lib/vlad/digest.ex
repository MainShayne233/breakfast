defmodule Vlad.Digest do
  defmodule Data do
    defstruct name: nil, fields: [], datas: []
  end

  defmodule Field do
    defstruct [:name, :type, :options]
  end

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

  defp digest_field([name, type | rest]) do
    %Field{name: name, type: type, options: Enum.at(rest, 0, [])}
  end
end
