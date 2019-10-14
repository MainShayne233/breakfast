defmodule Breakfast.ErrorContext do
  @moduledoc """
  A struct used for storing error context.
  """

  @enforce_keys [:error_type]
  @defaults [field_path: [], problem_value: :__na__]

  defstruct @enforce_keys ++ @defaults

  def prepend_field(context, field_name),
    do: %__MODULE__{context | field_path: [field_name | context.field_path]}
end
