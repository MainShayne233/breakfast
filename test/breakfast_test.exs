defmodule BreakfastTest do
  use ExUnit.Case
  import TestHelper
  doctest Breakfast

  testmodule Client.User do
    use Breakfast

    cereal do
      field(:email, String.t())
      field(:age, integer(), cast: :int_from_string)
      field(:timezone, String.t(), default: "US")
      field(:roles, [String.t()])

      field(:status, String.t(), fetch: :fetch_status, validate: :validate_status)
    end

    def fetch_status(params, :status), do: Map.fetch(params, "UserStatus")

    def validate_status(status) do
      if status in ["Approved", "Pending"] do
        []
      else
        ["invalid value"]
      end
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
      result = Breakfast.decode(Client.User, params)
      assert match?(%Breakfast.Yogurt{errors: []}, result)
    end

    test "should result in a parse error if a field is missing", %{params: params} do
      params = Map.delete(params, "age")
      result = Breakfast.decode(Client.User, params)

      assert match?(
               result,
               %Breakfast.Yogurt{
                 errors: [age: "value not found"]
               }
             )
    end

    @tag :only
    test "should result in a parse error if the custom parse function returns :error", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Cancelled")
      result = Breakfast.decode(Client.User, params)
      assert result.errors == [status: "invalid value"]
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

  testmodule DefaultParse.JSUser do
    use Breakfast

    cereal parse: &DefaultParse.JSUser.camel_key_fetch/2 do
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

  testmodule DefaultParseOverride.JSUser do
    use Breakfast

    cereal parse: &DefaultParse.camel_key_fetch/2 do
      field(:first_name, String.t())
      field(:last_name, String.t())
      field(:age, integer(), parse: :fetch_age)
    end

    def fetch_age(data), do: Map.fetch(data, "UserAge")

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

  # testmodule NestedDecoder do
  #   use Breakfast

  #   defmodule Config do
  #     use Breakfast

  #     cereal do
  #       field(:sleep_timeout, integer())
  #       field(:timezone, String.t())
  #     end
  #   end

  #   cereal do
  #     field(:email, String.t())
  #     field(:config, {:external, Config.t()})
  #   end

  #   test "should properly handle a nested decoder" do
  #     assert User.decode(%{
  #              "email" => "some@email.com",
  #              "config" => %{"sleep_timeout" => 50_000, "timezone" => "UTC"}
  #            }) ==
  #              {:ok,
  #               %User{
  #                 email: "some@email.com",
  #                 config: %User.Config{
  #                   sleep_timeout: 50_000,
  #                   timezone: "UTC"
  #                 }
  #               }}
  #   end
  # end

  # testmodule ExternalDecoder.User do
  #   use Breakfast

  #   defmodule Config do
  #     cereal do
  #       field(:sleep_timeout, integer())
  #       field(:timezone, String.t())
  #     end
  #   end

  #   cereal do
  #     field(:email, String.t())
  #     field(:config, {:external, BreakfastTest.ExternalDecoder.Config.t()})
  #   end

  #   test "should properly handle an externally defined decoder" do
  #     assert User.decode(%{
  #              "email" => "some@email.com",
  #              "config" => %{"sleep_timeout" => 50_000, "timezone" => "UTC"}
  #            }) ==
  #              {:ok,
  #               %User{
  #                 email: "some@email.com",
  #                 config: %Config{
  #                   sleep_timeout: 50_000,
  #                   timezone: "UTC"
  #                 }
  #               }}
  #   end
  # end

  # testmodule SuperNestedDecoder do
  #   use Breakfast

  #   cereal Decoder do
  #     field(:a, A.t())

  #     cereal A do
  #       field(:b, B.t())

  #       cereal B do
  #         field(:c, C.t())

  #         cereal C do
  #           field(:value, number())
  #         end
  #       end
  #     end
  #   end

  #   test "If a deeply nested decoder fails, the error should be reporting from that level" do
  #     params = %{"a" => %{"b" => %{"c" => %{"value" => 1}}}}

  #     assert match?(
  #              {:ok, _},
  #              SuperNestedDecoder.Decoder.decode(params)
  #            )

  #     params = put_in(params["a"]["b"]["c"]["value"], "")

  #     assert SuperNestedDecoder.Decoder.decode(params) ==
  #              {:error,
  #               %Breakfast.DecodeError{
  #                 field_path: [:a, :b, :c, :value],
  #                 input: params,
  #                 problem_value: "",
  #                 type: :validate_error,
  #                 message: """
  #                 The validation check failed for the value for the field at the following path: input[a -> b -> c -> value].

  #                 The value that failed the validate check was: "".

  #                 Either the value for this field was invalid, or the validate function for this
  #                 field isn't setup correctly. If the latter, check the docs on how to define custom validate functions.
  #                 """
  #               }}
  #   end
  # end
end
