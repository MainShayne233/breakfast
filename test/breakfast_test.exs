defmodule BreakfastTest do
  use ExUnit.Case
  import TestHelper
  doctest Breakfast

  testmodule Client do
    use Breakfast
    alias __MODULE__.User

    cereal User do
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
      params = Map.delete(params, "age")

      assert User.decode(params) ==
               {:error,
                %Breakfast.DecodeError{
                  type: :parse_error,
                  field_path: [:age],
                  input: params,
                  message: """
                  Failed to parse field at: input[age].

                  Either the input value did not have a parsable value for this field,
                  or the parsing isn't correctly setup for this field. If the latter, check
                  the docs on how to define custom parse functions.
                  """
                }}
    end

    test "should result in a parse error if the custom parse function returns :error", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Cancelled")

      assert User.decode(params) ==
               {:error,
                %Breakfast.DecodeError{
                  type: :parse_error,
                  field_path: [:status],
                  input: params,
                  message: """
                  Failed to parse field at: input[status].

                  Either the input value did not have a parsable value for this field,
                  or the parsing isn't correctly setup for this field. If the latter, check
                  the docs on how to define custom parse functions.
                  """
                }}
    end

    test "should raise a runtime exception if the custom parse returns a bad value", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Approved")

      assert assert_raise(Breakfast.DecodeError, fn ->
               User.decode(params)
             end) ==
               %Breakfast.DecodeError{
                 field_path: [:status],
                 input: params,
                 problem_value: "Approved",
                 type: :bad_parse_return,
                 message: """
                 An invalid value was returned by the parser for the field at: input[status].

                 Instead of returning {:ok, term()} | :error, the parse function for this field returned \"Approved\".
                 """
               }
    end

    test "should complain about invalid value for field", %{params: params} do
      params = Map.put(params, "email", :shayneAThotmailDOTcom)

      assert User.decode(params) ==
               {
                 :error,
                 %Breakfast.DecodeError{
                   field_path: [:email],
                   input: params,
                   problem_value: :shayneAThotmailDOTcom,
                   type: :validate_error,
                   message: """
                   The validation check failed for the value for the field at the following path: input[email].

                   The value that failed the validate check was: :shayneAThotmailDOTcom.

                   Either the value for this field was invalid, or the validate function for this
                   field isn't setup correctly. If the latter, check the docs on how to define custom validate functions.
                   """
                 }
               }
    end

    test "should complain about a bad cast", %{params: params} do
      params = Map.put(params, "age", :"10")

      assert User.decode(params) ==
               {
                 :error,
                 %Breakfast.DecodeError{
                   field_path: [:age],
                   input: params,
                   problem_value: :"10",
                   type: :cast_error,
                   message: """
                   The cast step failed for the value for the field at the following path: input[age].

                   The value that failed to cast was: :"10".

                   Either the value for this field was invalid, or the cast function for this
                   field isn't setup correctly. If the latter, check the docs on how to define custom cast functions.
                   """
                 }
               }
    end
  end

  testmodule InferValidator do
    use Breakfast

    test "should give a helpful error if unable to infer the validator for a custom type" do
      assert assert_raise(Breakfast.CompileError, fn ->
               defmodule Client do
                 use Breakfast
                 @type status :: :approved | :pending | :rejected

                 cereal Request do
                   field(:statuses, Client.status())
                 end
               end
             end)

      assert (defmodule Client do
                use Breakfast
                @type status :: :approved | :pending | :rejected

                cereal Request do
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

    cereal JSUser, default_parse: &DefaultParse.camel_key_fetch/2 do
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

    cereal JSUser, default_parse: &DefaultParse.camel_key_fetch/2 do
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

    cereal User do
      field(:email, String.t())
      field(:config, Config.t())

      cereal Config do
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

    cereal User do
      field(:email, String.t())
      field(:config, {:external, BreakfastTest.ExternalDecoder.Config.t()})
    end

    cereal Config do
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

  testmodule SuperNestedDecoder do
    use Breakfast

    cereal Decoder do
      field(:a, A.t())

      cereal A do
        field(:b, B.t())

        cereal B do
          field(:c, C.t())

          cereal C do
            field(:value, number())
          end
        end
      end
    end

    test "If a deeply nested decoder fails, the error should be reporting from that level" do
      params = %{"a" => %{"b" => %{"c" => %{"value" => 1}}}}

      assert match?(
               {:ok, _},
               SuperNestedDecoder.Decoder.decode(params)
             )

      params = put_in(params["a"]["b"]["c"]["value"], "")

      assert SuperNestedDecoder.Decoder.decode(params) ==
               {:error,
                %Breakfast.DecodeError{
                  field_path: [:a, :b, :c, :value],
                  input: params,
                  problem_value: "",
                  type: :validate_error,
                  message: """
                  The validation check failed for the value for the field at the following path: input[a -> b -> c -> value].

                  The value that failed the validate check was: "".

                  Either the value for this field was invalid, or the validate function for this
                  field isn't setup correctly. If the latter, check the docs on how to define custom validate functions.
                  """
                }}
    end
  end
end
