defmodule Breakfast.Cast do
  def string(term), do: {:ok, term}

  def integer(term) do
    case Integer.parse(term) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  def float(term) do
    case Float.parse(term) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end
end
