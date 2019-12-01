defmodule Breakfast.Util do
  @moduledoc false

  @type result(t) :: {:ok, t} | :error

  def hexdocs_from_markdown(path) do
    file = File.read!(path)
    Regex.replace(~r/\(#([a-z|-]+)\)/, file, "(#module-\\1)")
  end

  @spec maybe_map(Enumerable.t(), (term() -> result(term()))) ::
          result([term()])
  def maybe_map(enum, map) do
    Enum.reduce_while(enum, [], fn value, acc ->
      case map.(value) do
        {:ok, mapped_value} -> {:cont, [mapped_value | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      acc when is_list(acc) -> {:ok, Enum.reverse(acc)}
      :error -> :error
    end
  end
end
