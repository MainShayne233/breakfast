defmodule Breakfast.Field do
  @moduledoc false
  use TypedStruct

  @type type :: atom() | {:cereal, module()}

  typedstruct do
    field :mod, atom()
    field :name, atom()
    field :type, type()
    field :fetcher, atom()
    field :caster, atom()
    field :validator, atom()
    field :default, atom()
  end
end
