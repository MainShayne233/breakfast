defmodule Breakfast.Yogurt do
  defstruct params: nil, errors: [], struct: nil

  def valid?(%__MODULE__{errors: []}), do: true
  def valid?(%__MODULE__{errors: [_ | _]}), do: false
end
