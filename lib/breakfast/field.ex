defmodule Breakfast.Field do
  @moduledoc """
  The `%#{__MODULE__}{}` struct contains all the information related to a particular
  field on a struct created with `cereal`:

  - `mod`: The name of the module that defines this field
  - `name`: The name of the field
  - `type`: The type of the field
  - `fetcher`: The function that'll be used to fetch the value for this field
  - `caster`:  The function that'll be used to cast the value for this field
  - `validator`:  The function that'll be used to validate the value for this field
  - `default`:  The default value
  """
  use TypedStruct

  @type type :: atom() | {:cereal, module()} | {atom(), term()}

  typedstruct do
    field :mod, module()
    field :name, atom()
    field :type, type()
    field :fetcher, atom() | (any(), any() -> any()) | :default
    field :caster, atom() | (any() -> {:ok, any()} | :error) | :default
    field :validator, atom() | (any() -> [any()]) | :default
    field :default, {:ok, term()} | :error
  end
end
