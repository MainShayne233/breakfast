defmodule BreakfastTest do
  use ExUnit.Case
  import TestHelper
  doctest Breakfast

  testmodule Client do
    use Breakfast
    alias __MODULE__.User

    defdecoder User do
      field(:email, String.t())
      field(:age, integer(), cast: &Client.int_from_string/1)
      field(:timezone, String.t(), default: "US")
      field(:roles, [String.t()])

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

    setup do
      params = %{
        "email" => "shayne@hotmail.com",
        "age" => "10",
        "UserStatus" => "Pending",
        "roles" => ["user", "admin"]
      }

      %{params: params}
    end

    test "should succeed for valid params", %{params: params} do
      assert match?({:ok, %User{}}, User.decode(params))
    end

    test "should result in a parse error if a field is missing", %{params: params} do
      assert User.decode(Map.delete(params, "age")) ==
               {:error,
                %Breakfast.DecodeError{
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
                %Breakfast.DecodeError{
                  message: "Could not parse field from params",
                  type: :parse_error,
                  value: :status
                }}
    end

    test "should raise a runtime exception if the custom parse returns a bad value", %{
      params: params
    } do
      assert assert_raise(Breakfast.DecodeError, fn ->
               User.decode(Map.put(params, "UserStatus", "Approved"))
             end) == %Breakfast.DecodeError{
               message:
                 "The parse function defined for the field returned an invald type. Expected {:ok, term()} | :error, but got: \"Approved\"",
               type: :bad_parse_return,
               value: [field: :status, bad_return: "Approved"]
             }
    end

    test "should complain about invalid value for field", %{params: params} do
      assert User.decode(Map.put(params, "email", :shayneAThotmailDOTcom)) ==
               {:error,
                %Breakfast.DecodeError{
                  message: "Invalid value for field",
                  type: :validate_error,
                  value: {:email, :shayneAThotmailDOTcom}
                }}
    end

    test "should complain about a bad cast", %{params: params} do
      assert User.decode(Map.put(params, "age", :"10")) ==
               {:error,
                %Breakfast.DecodeError{
                  message: "Value failed to cast",
                  type: :cast_error,
                  value: {:age, :"10"}
                }}
    end
  end

  testmodule InferValidator do
    use Breakfast

    test "should give a helpful error if unable to infer the validator for a custom type" do
      assert assert_raise(Breakfast.CompileError, fn ->
               defmodule Client do
                 use Breakfast
                 @type status :: :approved | :pending | :rejected

                 defdecoder Request do
                   field(:statuses, Client.status())
                 end
               end
             end)

      assert (defmodule Client do
                use Breakfast
                @type status :: :approved | :pending | :rejected

                defdecoder Request do
                  field(:statuses, [Client.status()])

                  validate(Client.status(), fn value ->
                    value in [:approved, :pending, :rejected]
                  end)
                end
              end)
    end
  end

  testmodule DefaultParse do
    use Breakfast

    defdecoder JSUser, default_parse: &DefaultParse.camel_key_fetch/2 do
      field(:first_name, String.t())
      field(:last_name, String.t())
    end

    def camel_key_fetch(params, key) do
      {first_char, rest} = key |> to_string() |> Macro.camelize() |> String.split_at(1)
      camel_key = String.downcase(first_char) <> rest
      Map.fetch(params, camel_key)
    end

    test "should use the :default_parse function if one is defined" do
      assert JSUser.decode(%{"firstName" => "shawn", "lastName" => "trembles"}) ==
               {:ok,
                %JSUser{
                  first_name: "shawn",
                  last_name: "trembles"
                }}
    end
  end

  testmodule DefaultParseOverride do
    use Breakfast

    defdecoder JSUser, default_parse: &DefaultParse.camel_key_fetch/2 do
      field(:first_name, String.t())
      field(:last_name, String.t())
      field(:age, integer(), parse: &Map.fetch(&1, "UserAge"))
    end

    def camel_key_fetch(params, key) do
      {first_char, rest} = key |> to_string() |> Macro.camelize() |> String.split_at(1)
      camel_key = String.downcase(first_char) <> rest
      Map.fetch(params, camel_key)
    end

    test "should use the :default_parse function if one is defined" do
      assert JSUser.decode(%{"firstName" => "shawn", "lastName" => "trembles", "UserAge" => 28}) ==
               {:ok,
                %JSUser{
                  first_name: "shawn",
                  last_name: "trembles",
                  age: 28
                }}
    end
  end

  testmodule NestedDecoder do
    use Breakfast

    defdecoder User do
      field(:email, String.t())
      field(:config, Config.t())

      defdecoder Config do
        field(:sleep_timeout, integer())
        field(:timezone, String.t())
      end
    end

    test "should properly handle a nested decoder" do
      assert User.decode(%{
               "email" => "some@email.com",
               "config" => %{"sleep_timeout" => 50_000, "timezone" => "UTC"}
             }) ==
               {:ok,
                %User{
                  email: "some@email.com",
                  config: %User.Config{
                    sleep_timeout: 50_000,
                    timezone: "UTC"
                  }
                }}
    end
  end

  testmodule ExternalDecoder do
    use Breakfast

    defdecoder User do
      field(:email, String.t())
      field(:config, {:external, BreakfastTest.ExternalDecoder.Config.t()})
    end

    defdecoder Config do
      field(:sleep_timeout, integer())
      field(:timezone, String.t())
    end

    test "should properly handle an externally defined decoder" do
      assert User.decode(%{
               "email" => "some@email.com",
               "config" => %{"sleep_timeout" => 50_000, "timezone" => "UTC"}
             }) ==
               {:ok,
                %User{
                  email: "some@email.com",
                  config: %Config{
                    sleep_timeout: 50_000,
                    timezone: "UTC"
                  }
                }}
    end
  end
end
