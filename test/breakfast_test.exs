defmodule Client do
  use Breakfast

  defdata User do
    field(:email, String.t())
    field(:age, integer(), cast: &Client.int_from_string/1)
    field(:timezone, String.t(), default: "US")

    field(:status, String.t(),
      parse: fn
        %{"UserStatus" => "Pending"} -> {:ok, "Pending"}
        %{"UserStatus" => "Approved"} -> "Approved"
        _other -> :error
      end
    )
  end

  def int_from_string(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _other -> :error
    end
  end

  def int_from_string(_), do: :error
end

defmodule BreakfastTest do
  use ExUnit.Case
  alias Client.User
  doctest Breakfast

  setup do
    params = %{
      "email" => "shayne@hotmail.com",
      "age" => "10",
      "UserStatus" => "Pending"
    }

    %{params: params}
  end

  test "should succeed for valid params", %{params: params} do
    assert match?({:ok, %User{}}, User.decode(params))
  end

  test "should result in a parse error if a field is missing", %{params: params} do
    assert User.decode(Map.delete(params, "age")) ==
             {:error,
              %Breakfast.Error{
                message: "Could not parse field from params",
                type: :parse_error,
                value: :age
              }}
  end

  test "should result in a parse error if the custom parse function returns :error", %{
    params: params
  } do
    assert User.decode(Map.put(params, "UserStatus", "Canclled")) ==
             {:error,
              %Breakfast.Error{
                message: "Could not parse field from params",
                type: :parse_error,
                value: :status
              }}
  end

  test "should raise a runtime exception if the custom parse returns a bad value", %{
    params: params
  } do
    assert assert_raise(RuntimeError, fn ->
             User.decode(Map.put(params, "UserStatus", "Approved"))
           end) == %RuntimeError{
             message:
               "Bad return from parse from field: status. Expected {:ok, term()} | :error, got: \"Approved\""
           }
  end

  test "should complain about invalid value for field", %{params: params} do
    assert User.decode(Map.put(params, "email", :shayneAThotmailDOTcom)) ==
             {:error,
              %Breakfast.Error{
                message: "Invalid value for field",
                type: :validate_error,
                value: {:email, :shayneAThotmailDOTcom}
              }}
  end

  test "should complain about a bad cast", %{params: params} do
    assert User.decode(Map.put(params, "age", :"10")) ==
             {:error,
              %Breakfast.Error{
                message: "Value failed to cast",
                type: :cast_error,
                value: {:age, :"10"}
              }}
  end
end
