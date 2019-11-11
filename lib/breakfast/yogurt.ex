defmodule Breakfast.Yogurt do
  use TypedStruct

  typedstruct do
    field :params, term(), default: nil
    field :errors, [String.t()], default: []
    field :struct, struct(), default: nil
  end

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{errors: []}), do: true
  def valid?(%__MODULE__{errors: [_ | _]}), do: false
end
