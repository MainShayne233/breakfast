defmodule Breakfast.Validate do

  def string(term) when is_binary(term), do: []
  def string(term), do: ["Expected #{inspect(term)} to be a string"]

  def integer(term) when is_integer(term), do: []
  def integer(term), do: ["Expected #{inspect(term)} to be a integer"]

  def float(term) when is_float(term), do: []
  def float(term), do: ["Expected #{inspect(term)} to be a float"]
end
