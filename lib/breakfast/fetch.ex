defmodule Breakfast.Fetch do
  def string(map, key), do: Map.fetch(map, to_string(key))

  def atom(map, key), do: Map.fetch(map, key)

  def camel_case_string(map, key), do: Map.fetch(map, key)
end
