defmodule Breakfast.Type do
  def cast(:string, term) when is_binary(term), do: {:ok, term}
  def cast(:string, _term), do: :error

  def cast(:integer, term) when is_integer(term), do: {:ok, term}

  def cast(:integer, term) when is_binary(term) do
    case Integer.parse(term) do
      {integer, _} -> {:ok, integer}
      _ -> :error
    end
  end

  def cast(:float, term) when is_float(term), do: {:ok, term}

  def cast(:float, term) when is_binary(term) do
    case Float.parse(term) do
      {float, _} -> {:ok, float}
      _ -> :error
    end
  end

  def cast(:number, term) when is_number(term), do: {:ok, term}

  def cast(:number, term) when is_binary(term) do
    with :error <- Integer.parse(term),
         :error <- Float.parse(term),
         do: :error,
         else: ({number, _} -> :error)
  end

  def cast({:list, type}, term) when is_list(term) do
    list_or_error =
      Enum.reduce_while(term, [], fn t, acc ->
        case cast(type, t) do
          {:ok, t} -> {:cont, [t | acc]}
          :error -> {:halt, :error}
        end
      end)

    with list when is_list(list) <- list_or_error, do: {:ok, Enum.reverse(list)}
  end

  def cast({:list, _type}, term), do: :error

  def validate(:string, term) when is_binary(term), do: []
  def validate(:string, term), do: ["expected a string, got #{inspect(term)}"]

  def validate(:integer, term) when is_integer(term), do: []
  def validate(:integer, term), do: ["expected an integer, got #{inspect(term)}"]

  def validate(:float, term) when is_float(term), do: []
  def validate(:float, term), do: ["expected a float, got #{inspect(term)}"]

  def validate(:number, term) when is_number(term), do: []
  def validate(:number, term), do: ["expected a number, got #{inspect(term)}"]

  def validate({:list, type}, term) when is_list(term) do
    Enum.reduce_while(term, [], fn t, acc ->
      case validate(type, t) do
        [] -> {:cont, []}
        [_ | _] = errors -> {:halt, errors}
      end
    end)
  end

  def validate({:list, _type}, term), do: ["expected a list, got #{inspect(term)}"]
end
