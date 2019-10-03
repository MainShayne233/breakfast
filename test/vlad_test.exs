use Vlad

defdata User do
  field(:email, :string)
  field(:age, :integer, cast: &VladTest.int_from_string/1)
  field(:timezone, :string, default: "US")
end

defmodule VladTest do
  use ExUnit.Case
  doctest Vlad

  test "should require all fields that were not defined with a default value" do
    assert User.validate(%{}) ==
             {:error,
              %Vlad.Error{
                message: "Missing fields in params.",
                type: :missing_fields,
                value: [:email, :age]
              }}

    assert User.validate(%{"email" => "shayne@hotmail.com", "age" => "10"}) ==
             {:ok, struct!(User, email: "shayne@hotmail.com", timezone: "US", age: 10)}
  end

  test "should complain about extraneous fields being provided" do
    assert User.validate(%{
             "email" => "shayne@hotmail.com",
             "age" => "10",
             "birthday" => "10/09/95"
           }) ==
             {:error,
              %Vlad.Error{
                message: "Extraneous field in params.",
                type: :extraneous_field,
                value: "birthday"
              }}
  end

  test "should complain about invalid value for field" do
    assert User.validate(%{"email" => :shayneAThotmailDOTcom}) ==
             {:error,
              %Vlad.Error{
                message: "Invalid value for field",
                type: :invalid_field_value,
                value: {:email, :shayneAThotmailDOTcom}
              }}
  end

  test "should complain about a bad cast" do
    assert User.validate(%{"email" => "shayne@hotmail.com", "age" => :"10"}) ==
             {:error,
              %Vlad.Error{
                message: "Value failed to cast",
                type: :cast_failure,
                value: {:age, :"10"}
              }}
  end

  def int_from_string(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _other -> :error
    end
  end

  def int_from_string(_), do: :error
end
