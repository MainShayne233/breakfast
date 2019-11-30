defmodule Breakfast.Util do
  @moduledoc false

  def hexdocs_from_markdown(path) do
    file = File.read!(path)
    Regex.replace(~r/\(#([a-z|-]+)\)/, file, "(#module-\\1)")
  end
end
