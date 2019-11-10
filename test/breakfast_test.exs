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

    def validate_status("Pending"), do: []
    def validate_status("Approved"), do: :bad_return
    def validate_status(_other), do: ["invalid value"]

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

      assert result.errors == [age: "value not found"]
    end

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

      assert assert_raise(RuntimeError, fn ->
               Breakfast.decode(Client.User, params)
             end) == %RuntimeError{
               message:
                 "Expected status.validate (:validate_status) to return a list, got :bad_return"
             }
    end

    test "a bad type should result in a cast error", %{params: params} do
      params = Map.put(params, "email", :shayneAThotmailDOTcom)
      result = Breakfast.decode(Client.User, params)

      assert result.errors == [email: "cast error"]
    end
  end

  testmodule InferValidator do
    use Breakfast

    @tag :only
    test "should give a helpful error if unable to infer the validator for a custom type" do
      defmodule Client.Request do
        use Breakfast

        cereal do
          field(:statuses, Breakfast.TestDefinitions.status())
        end
      end
    end
  end

  testmodule DefaultParse.JSUser do
    use Breakfast

    cereal fetch: &DefaultParse.JSUser.camel_key_fetch/2 do
      field(:first_name, String.t())
      field(:last_name, String.t())
    end

    def camel_key_fetch(params, key) do
      {first_char, rest} = key |> to_string() |> Macro.camelize() |> String.split_at(1)
      camel_key = String.downcase(first_char) <> rest
      Map.fetch(params, camel_key)
    end

    test "should use the :default_parse function if one is defined" do
      params = %{"firstName" => "shawn", "lastName" => "trembles"}
      result = Breakfast.decode(__MODULE__, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: %{"firstName" => "shawn", "lastName" => "trembles"},
               struct: %__MODULE__{
                 first_name: "shawn",
                 last_name: "trembles"
               }
             }
    end
  end

  testmodule DefaultParseOverride.JSUser do
    use Breakfast

    cereal fetch: &__MODULE__.camel_key_fetch/2 do
      field(:first_name, String.t())
      field(:last_name, String.t())
      field(:age, integer(), fetch: :fetch_age)
    end

    def fetch_age(data, :age), do: Map.fetch(data, "UserAge")

    def camel_key_fetch(params, key) do
      {first_char, rest} = key |> to_string() |> Macro.camelize() |> String.split_at(1)
      camel_key = String.downcase(first_char) <> rest
      Map.fetch(params, camel_key)
    end

    test "should use the field-level fetch over the default fetch" do
      params = %{"firstName" => "shawn", "lastName" => "trembles", "UserAge" => 28}
      result = Breakfast.decode(__MODULE__, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: %{"UserAge" => 28, "firstName" => "shawn", "lastName" => "trembles"},
               struct: %BreakfastTest.DefaultParseOverride.JSUser{
                 age: 28,
                 first_name: "shawn",
                 last_name: "trembles"
               }
             }
    end
  end

  testmodule External do
    use Breakfast

    defmodule Config do
      use Breakfast

      cereal do
        field(:sleep_timeout, integer())
        field(:timezone, String.t())
      end
    end

    cereal do
      field(:email, String.t())
      field(:config, {:cereal, Config})
    end

    test "should properly handle an externally defined cereal" do
      params = %{
        "email" => "some@email.com",
        "config" => %{"sleep_timeout" => 50_000, "timezone" => "UTC"}
      }

      result = Breakfast.decode(__MODULE__, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: params,
               struct: %BreakfastTest.External{
                 config: %BreakfastTest.External.Config{
                   sleep_timeout: 50000,
                   timezone: "UTC"
                 },
                 email: "some@email.com"
               }
             }
    end

    test "nested decoding errors should bubble up to top level yogurt" do
      bad_params = %{
        "email" => "some@email.com",
        "config" => %{"sleep_timeout" => [], "timezone" => :UTC}
      }

      result = Breakfast.decode(__MODULE__, bad_params)

      assert result.errors == [config: [timezone: "cast error", sleep_timeout: "cast error"]]
    end
  end

  testmodule SuperNestedDecoder do
    use Breakfast

    defmodule A do
      use Breakfast

      defmodule B do
        use Breakfast

        defmodule C do
          use Breakfast

          cereal do
            field(:value, number())
          end
        end

        cereal do
          field(:c, {:cereal, C})
        end
      end

      cereal do
        field(:b, {:cereal, B})
      end
    end

    cereal do
      field(:a, {:cereal, A})
    end

    test "If a deeply nested decoder fails, the error should be reporting from that level" do
      params = %{"a" => %{"b" => %{"c" => %{"value" => 1}}}}
      result = Breakfast.decode(SuperNestedDecoder, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: %{"a" => %{"b" => %{"c" => %{"value" => 1}}}},
               struct: %BreakfastTest.SuperNestedDecoder{
                 a: %BreakfastTest.SuperNestedDecoder.A{
                   b: %BreakfastTest.SuperNestedDecoder.A.B{
                     c: %BreakfastTest.SuperNestedDecoder.A.B.C{value: 1}
                   }
                 }
               }
             }
    end
  end
end
