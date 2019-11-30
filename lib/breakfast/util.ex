defmodule Breakfast.Util do
  @moduledoc false

  @type result(t) :: {:ok, t} | :error

  def hexdocs_from_markdown(path) do
    file = File.read!(path)
    Regex.replace(~r/\(#([a-z|-]+)\)/, file, "(#module-\\1)")
  end
end
