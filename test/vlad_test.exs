defmodule VladTest do
  use ExUnit.Case
  doctest Vlad

  use Vlad

  test "should " do
    defdata User do
      field(:email, :string)
    end

    assert User.validate(%{}) ==
             {:error,
              %Vlad.ValidateError{
                message: "Missing fields in params.",
                type: :missing_fields,
                value: [:email]
              }}
  end
end
