defmodule Breakfast.Cast do
  def string(term) when is_binary(term), do: {:ok, term}
  def string(_term), do: :error

  def integer(term) when is_integer(term), do: {:ok, term}
  def integer(term) when is_binary(term) do
    case Integer.parse(term) do
      {integer, ""} -> {:ok, integer}
      _ -> :error
    end
  end

  def float(term) when is_float(term), do: {:ok, term}
  def float(term) when is_binary(term) do
    case Float.parse(term) do
      {float, ""} -> {:ok, float}
      _ -> :error
    end
  end
end
