defmodule Breakfast.DecodeError do
  @moduledoc """
  Defines exceptions that can occur when data is being decoded.
  """

  alias Breakfast.ErrorContext

  defexception [:type, :message, {:field_path, []}, :input, {:problem_value, :__na__}]

  def from_context(
        %ErrorContext{
          error_type: :parse_error,
          field_path: field_path
        },
        input
      ) do
    %__MODULE__{
      type: :parse_error,
      field_path: field_path,
      input: input,
      message: """
      Failed to parse field at: #{field_path_display(field_path)}.

      Either the input value did not have a parsable value for this field,
      or the parsing isn't correctly setup for this field. If the latter, check
      the docs on how to define custom parse functions.
      """
    }
  end

  def from_context(
        %Breakfast.ErrorContext{
          error_type: :bad_parse_return,
          field_path: field_path,
          problem_value: problem_value
        },
        input
      ) do
    %__MODULE__{
      type: :bad_parse_return,
      field_path: field_path,
      input: input,
      problem_value: problem_value,
      message: """
      An invalid value was returned by the parser for the field at: #{
        field_path_display(field_path)
      }.

      Instead of returning {:ok, term()} | :error, the parse function for this field returned #{
        inspect(problem_value)
      }.
      """
    }
  end

  def from_context(
        %Breakfast.ErrorContext{
          error_type: :validate_error,
          field_path: field_path,
          problem_value: problem_value
        },
        input
      ) do
    %__MODULE__{
      type: :validate_error,
      field_path: field_path,
      input: input,
      problem_value: problem_value,
      message: """
      The validation check failed for the value for the field at the following path: #{
        field_path_display(field_path)
      }.

      The value that failed the validate check was: #{inspect(problem_value)}.

      Either the value for this field was invalid, or the validate function for this
      field isn't setup correctly. If the latter, check the docs on how to define custom validate functions.
      """
    }
  end

  def from_context(
        %Breakfast.ErrorContext{
          error_type: :cast_error,
          field_path: field_path,
          problem_value: problem_value
        },
        input
      ) do
    %__MODULE__{
      type: :cast_error,
      field_path: field_path,
      input: input,
      problem_value: problem_value,
      message: """
      The cast step failed for the value for the field at the following path: #{
        field_path_display(field_path)
      }.

      The value that failed to cast was: #{inspect(problem_value)}.

      Either the value for this field was invalid, or the cast function for this
      field isn't setup correctly. If the latter, check the docs on how to define custom cast functions.
      """
    }
  end

  defp field_path_display(paths) do
    "input[" <> Enum.join(paths, " -> ") <> "]"
  end
end
