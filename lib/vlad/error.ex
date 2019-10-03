defmodule Vlad.Error do
  defexception [:type, :value, :message]

  def new_missing_fields_error(missing_fields),
    do: %__MODULE__{
      type: :missing_fields,
      value: missing_fields,
      message: "Missing fields in params."
    }

  def new_extraneous_field_error(extraneous_field),
    do: %__MODULE__{
      type: :extraneous_field,
      value: extraneous_field,
      message: "Extraneous field in params."
    }

  def new_invalid_value_error(field_name, value),
    do: %__MODULE__{
      type: :invalid_field_value,
      value: {field_name, value},
      message: "Invalid value for field"
    }

  def new_cast_failure_error(field_name, value),
    do: %__MODULE__{
      type: :cast_failure,
      value: {field_name, value},
      message: "Value failed to cast"
    }
end
