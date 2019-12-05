defmodule Breakfast.Yogurt do
  @moduledoc """
  The `%#{__MODULE__}{}` struct is the resulting value of a call to `Breakfast.decode/2`.

  It contains all the information regarding a particular decode, including:
  - the params passed in
  - errors that occured for a given field
  - the resulting, decoded struct
  """
  use TypedStruct

  typedstruct do
    field :params, term(), default: nil
    field :errors, [String.t()], default: []
    field :struct, struct(), default: nil
    field :fields, [Breakfast.Field.t()], default: []
  end

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{errors: []}), do: true
  def valid?(%__MODULE__{errors: [_ | _]}), do: false
end
