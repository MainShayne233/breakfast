defmodule Breakfast.CompileError do
  @moduledoc """
  Defines errors that can occur at compile time.
  """

  @type t :: %__MODULE__{
    type: atom(),
    value: term(),
    message: String.t()
  }

  defexception [:type, :value, :message]

  @spec new_module_define_error(module_name :: Breakfast.quoted(), error :: t()) :: t()
  def new_module_define_error(module_name, error),
    do: %__MODULE__{
      type: :module_define_error,
      value: [name: String.to_atom("Elixir." <> Macro.to_string(module_name)), error: error],
      message: """


      Failed to define the defdecoder for #{Macro.to_string(module_name)}.

      Underyling error:

      #{error.message}
      """
    }

  @spec new_validator_inference_error(
          field_name :: atom(),
          field_type :: Breakfast.quoted(),
          bad_type :: Breakfast.quoted()
        ) :: t()
  def new_validator_inference_error(field_name, field_type, bad_type),
    do: %__MODULE__{
      type: :validator_inference,
      value: [field: field_name, type: Macro.to_string(bad_type)],
      message: validator_inference_message(field_name, field_type, bad_type)
    }

  @spec validator_inference_message(field_name :: atom(), field_type :: Breakfast.quoted(), bad_type :: Breakfast.quoted()) :: String.t()
  defp validator_inference_message(field_name, field_type, field_type),
    do: """
    Cannot infer validator for field: #{field_name}. It is unclear how to validate the field's type: #{
      Macro.to_string(field_type)
    }.

    You can define a validate function inline with the field, like:

    defdecoder ... do
      field(#{field_name}, #{Macro.to_string(field_type)}, validate: fn value -> ... end)
    end

    Or, you can define the validate function seperatly:

    defdecoder ... do
      field(#{field_name}, #{Macro.to_string(field_type)})

      validate(#{Macro.to_string(field_type)}, fn value -> ... end)
    end
    """

  defp validator_inference_message(field_name, field_type, bad_type),
    do: """
    Cannot infer validator for field: #{field_name}.

    It is unclear how to validate the following type used by the field: #{
      Macro.to_string(bad_type)
    }.

    You can add a validate function to define the way to validate this type like so:

    defdecoder ... do
      field(#{field_name}, #{Macro.to_string(field_type)})

      validate(#{Macro.to_string(bad_type)}, fn value ->
        if ... do
          :ok
        else
          :error
        end
      end)
    end
    """
end
