defmodule Breakfast.ErrorContext do
  @moduledoc """
  A struct used for storing error context.
  """

  @type t :: %__MODULE__{
          error_type: atom(),
          field_path: [field_name :: atom()],
          problem_value: term()
        }

  @enforce_keys [:error_type]
  @defaults [field_path: [], problem_value: :__na__]

  defstruct @enforce_keys ++ @defaults

  @spec prepend_field(t(), field_name :: atom()) :: t()
  def prepend_field(context, field_name),
    do: %__MODULE__{context | field_path: [field_name | context.field_path]}
end
