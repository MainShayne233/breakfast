defmodule Breakfast.DecodeError do
  @moduledoc """
  Defines exceptions that can occur when data is being decoded.
  """

  defexception [:type, :value, :message]

  def new_parse_error(fieldname),
    do: %__MODULE__{
      type: :parse_error,
      value: fieldname,
      message: "Could not parse field from params"
    }

  def new_validate_error(field_name, value),
    do: %__MODULE__{
      type: :validate_error,
      value: {field_name, value},
      message: "Invalid value for field"
    }

  def new_cast_error(field_name, value),
    do: %__MODULE__{
      type: :cast_error,
      value: {field_name, value},
      message: "Value failed to cast"
    }

  [
    parse: "{:ok, term()} | :error",
    cast: "{:ok, term()} | :error",
    validate: ":ok | :error"
  ]
  |> Enum.map(fn {func_type, expected_pattern} ->
    def unquote(String.to_atom("new_bad_#{func_type}_return_error"))(field_name, value),
      do: %__MODULE__{
        type: String.to_atom("bad_#{unquote(func_type)}_return"),
        value: [field: field_name, bad_return: value],
        message:
          "The #{unquote(func_type)} function defined for the field returned an invald type. Expected #{
            unquote(expected_pattern)
          }, but got: #{inspect(value)}"
      }
  end)
end
