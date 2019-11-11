defmodule BreakfastTest do
  use ExUnit.Case
  doctest Breakfast

  describe "basic validations" do
    setup do
      params = %{
        "email" => "shayne@hotmail.com",
        "age" => "10",
        "UserStatus" => "Pending",
        "roles" => ["user", "admin"]
      }

      %{params: params}
    end

    defmodule Customer do
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
    end

    test "should succeed for valid params", %{params: params} do
      result = Breakfast.decode(Customer, params)
      assert match?(%Breakfast.Yogurt{errors: []}, result)
    end

    test "should result in a parse error if a field is missing", %{params: params} do
      params = Map.delete(params, "age")
      result = Breakfast.decode(Customer, params)

      assert result.errors == [age: "value not found"]
    end

    test "should result in a parse error if the custom parse function returns :error", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Cancelled")
      result = Breakfast.decode(Customer, params)
      assert result.errors == [status: "invalid value"]
    end

    test "should raise a runtime exception if the custom parse returns a bad value", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Approved")

      assert assert_raise(RuntimeError, fn ->
               Breakfast.decode(Customer, params)
             end) == %RuntimeError{
               message:
                 "Expected status.validate (:validate_status) to return a list, got: :bad_return"
             }
    end

    test "a bad type should result in a cast error", %{params: params} do
      params = Map.put(params, "email", :shayneAThotmailDOTcom)
      result = Breakfast.decode(Customer, params)

      assert result.errors == [email: "expected a binary, got: :shayneAThotmailDOTcom"]
    end
  end

  describe "fetching" do
    setup do
      params = %{"firstName" => "shawn", "lastName" => "trembles", "UserAge" => 28}
      %{params: params}
    end

    defmodule JSUser do
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
    end

    test "should respect fetch presedence", %{params: params} do
      result = Breakfast.decode(JSUser, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: %{"UserAge" => 28, "firstName" => "shawn", "lastName" => "trembles"},
               struct: %JSUser{
                 age: 28,
                 first_name: "shawn",
                 last_name: "trembles"
               }
             }
    end
  end

  describe "externally defined cereals" do
    defmodule Server do
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
    end

    test "should properly handle an externally defined cereal" do
      params = %{
        "email" => "some@email.com",
        "config" => %{"sleep_timeout" => 50_000, "timezone" => "UTC"}
      }

      result = Breakfast.decode(Server, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: params,
               struct: %Server{
                 config: %Server.Config{
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

      result = Breakfast.decode(Server, bad_params)

      assert result.errors == [
               config: [
                 timezone: "expected a binary, got: :UTC",
                 sleep_timeout: "expected a integer, got: []"
               ]
             ]
    end
  end

  describe "arbitrary nesting" do
    setup do
      params = %{"a" => %{"b" => %{"c" => %{"value" => 1}}}}
      %{params: params}
    end

    defmodule SuperNestedDecoder do
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
    end

    test "If a deeply nested decoder fails, the error should be reporting from that level", %{
      params: params
    } do
      result = Breakfast.decode(SuperNestedDecoder, params)

      assert result == %Breakfast.Yogurt{
               errors: [],
               params: %{"a" => %{"b" => %{"c" => %{"value" => 1}}}},
               struct: %SuperNestedDecoder{
                 a: %SuperNestedDecoder.A{
                   b: %SuperNestedDecoder.A.B{
                     c: %SuperNestedDecoder.A.B.C{value: 1}
                   }
                 }
               }
             }
    end
  end

  describe "complex types" do
    setup do
      %{
        params: %{
          "rgb_color" => "blue",
          "tag_groupings" => [["guest"], ["user", "admin"]],
          "ratio" => [1, 2]
        }
      }
    end

    defmodule ColorData do
      use Breakfast

      cereal do
        field :rgb_color, Breakfast.TestDefinitions.rgb_color(), cast: :string_to_existing_atom
        field :tag_groupings, [[String.t()]]
        field :ratio, {integer(), integer()}, cast: :pair_from_list
      end

      def pair_from_list([lhs, rhs]), do: {:ok, {lhs, rhs}}
      def pair_from_list(_), do: :error

      def string_to_existing_atom(binary) do
        {:ok, String.to_existing_atom(binary)}
      rescue
        _ in ArgumentError ->
          :error
      end
    end

    test "should handle union types", %{params: params} do
      result = Breakfast.decode(ColorData, params)
      assert result.errors == []

      params = %{params | "rgb_color" => "green"}
      result = Breakfast.decode(ColorData, params)
      assert result.errors == []

      params = %{params | "rgb_color" => "cyan"}
      result = Breakfast.decode(ColorData, params)

      assert result.errors == [
               rgb_color:
                 "expected one of [literal: :red, literal: :green, literal: :blue], got: :cyan"
             ]
    end

    test "should handle multi-dimensional lists", %{params: params} do
      result = Breakfast.decode(ColorData, params)
      assert result.errors == []

      params = %{params | "tag_groupings" => ["user", "admin"]}

      result = Breakfast.decode(ColorData, params)
      assert result.errors == [tag_groupings: "expected a list, got: \"user\""]
    end

    test "should support tuples", %{params: params} do
      result = Breakfast.decode(ColorData, params)
      assert result.errors == []

      params = %{params | "ratio" => [7, 5.0]}
      result = Breakfast.decode(ColorData, params)
      assert result.errors == [ratio: "expected {:integer, :integer}, got: {7, 5.0}"]
    end
  end

  describe "errors" do
    test "should raise error when type cannot be determined" do
      assert assert_raise(RuntimeError, fn ->
               defmodule WillRaise do
                 use Breakfast

                 cereal do
                   field :crazy, DoesNotExist.t()
                 end
               end
             end) == %RuntimeError{message: "Failed to derive type from spec: DoesNotExist.t()"}
    end
  end

  describe "README examples" do
    defmodule READMEExampleOne do
      defmodule User do
        use Breakfast

        cereal do
          field :email, String.t()
          field :age, integer()
          field :roles, [String.t()]
        end
      end
    end

    defmodule READMEExampleTwo do
      defmodule User do
        use Breakfast

        cereal do
          field :email, String.t()
          field :age, integer()
          field :roles, [String.t()], fetch: :fetch_roles
        end

        def fetch_roles(params, :roles), do: Map.fetch(params, "UserRoles") |> IO.inspect()
      end
    end

    test "should decode plain elixir maps with string, snake_case keys" do
      params = %{
        "email" => "my@email.com",
        "age" => 20,
        "roles" => ["user", "exec"]
      }

      assert Breakfast.decode(READMEExampleOne.User, params) ==
               %Breakfast.Yogurt{
                 errors: [],
                 params: %{"age" => 20, "email" => "my@email.com", "roles" => ["user", "exec"]},
                 struct: %READMEExampleOne.User{
                   age: 20,
                   email: "my@email.com",
                   roles: ["user", "exec"]
                 }
               }

      assert Breakfast.decode(READMEExampleOne.User, %{params | "age" => 20.5}) ==
               %Breakfast.Yogurt{
                 errors: [age: "expected a integer, got: 20.5"],
                 params: %{
                   "age" => 20.5,
                   "email" => "my@email.com",
                   "roles" => ["user", "exec"]
                 },
                 struct: %READMEExampleOne.User{
                   age: nil,
                   email: "my@email.com",
                   roles: ["user", "exec"]
                 }
               }
    end

    test "should should respect a custom :fetch function" do
      params = %{
        "email" => "my@email.com",
        "age" => 20,
        "UserRoles" => ["user", "exec"]
      }

      assert Breakfast.decode(READMEExampleTwo.User, params) ==
               %Breakfast.Yogurt{
                 errors: [],
                 params: %{
                   "age" => 20,
                   "email" => "my@email.com",
                   "UserRoles" => ["user", "exec"]
                 },
                 struct: %READMEExampleTwo.User{
                   age: 20,
                   email: "my@email.com",
                   roles: ["user", "exec"]
                 }
               }
    end
  end
end
