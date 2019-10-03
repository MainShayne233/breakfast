defmodule VladTest do
  use ExUnit.Case
  doctest Vlad

  use Vlad

  test "should require all fields that were not defined with a default value" do
    defdata User do
      field(:email, :string)
      field(:timezone, :string, default: "US")
    end

    assert User.validate(%{}) ==
             {:error,
              %Vlad.ValidateError{
                message: "Missing fields in params.",
                type: :missing_fields,
                value: [:email]
              }}

    assert User.validate(%{"email" => "shayne@hotmail.com"}) ==
             {:ok, struct!(VladTest.User, email: "shayne@hotmail.com", timezone: "US")}
  end
end
