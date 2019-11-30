defmodule BreakfastTest do
  use ExUnit.Case
  use MarkdownTest

  doctest Breakfast, except: [{:decode, 2}, :moduledoc]
  test_markdown("README.md")
  test_markdown("TYPES.md")

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

    test "should result in a parse error if the custom validate function returns :error", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Cancelled")
      result = Breakfast.decode(Customer, params)
      assert result.errors == [status: "invalid value"]
    end

    test "should raise a runtime exception if the custom validate returns a bad value", %{
      params: params
    } do
      params = Map.put(params, "UserStatus", "Approved")

      %Breakfast.ValidateError{message: message, field: field, type: type, validator: validator} =
        assert_raise Breakfast.ValidateError, fn ->
          Breakfast.decode(Customer, params)
        end

      assert "Expected validator for `status` (`:validate_status`) to return a list, got: `:bad_return`" =
               message

      assert :status = field
      assert :binary = type
      assert :validate_status = validator
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

      def fetch_age(%{bad_return: true}, :age), do: :bad_return
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

    test "should raise a runtime exception if the custom fetch returns a bad value", %{
      params: params
    } do
      params = Map.put(params, :bad_return, true)

      %Breakfast.FetchError{message: message, field: field, type: type, fetcher: fetcher} =
        assert_raise Breakfast.FetchError, fn ->
          Breakfast.decode(JSUser, params)
        end

      assert "Expected fetcher for `age` (`:fetch_age`) to return `{:ok, value}` or `:error`, got: `:bad_return`" =
               message

      assert :age = field
      assert :integer = type
      assert :fetch_age = fetcher
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
                 sleep_timeout: "expected a integer, got: []",
                 timezone: "expected a binary, got: :UTC"
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
               rgb_color: "expected one of :red | :green | :blue, got: :cyan"
             ]
    end

    test "should handle multi-dimensional lists", %{params: params} do
      result = Breakfast.decode(ColorData, params)
      assert result.errors == []

      params = %{params | "tag_groupings" => ["user", "admin"]}

      result = Breakfast.decode(ColorData, params)

      assert result.errors == [
               tag_groupings:
                 "expected a list of type {:list, :binary}, got a list with at least one invalid element: expected a list of type :binary, got: \"user\", expected a list of type :binary, got: \"admin\""
             ]
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
    test "should raise a compile-time error when `type` is missing an option" do
      %Breakfast.CompileError{message: message} =
        assert_raise Breakfast.CompileError, fn ->
          defmodule WillRaise do
            use Breakfast

            cereal do
              type atom(), []
            end
          end
        end

      assert "\n\n  Expected a :fetch, :cast or :validate for `type atom()`:" <> _ = message
    end

    test "should raise a compile-time error when the options for cereal are invalid" do
      %Breakfast.CompileError{message: message} =
        assert_raise Breakfast.CompileError, fn ->
          defmodule WillRaise do
            use Breakfast

            cereal :not_a_list do
              type atom(), []
            end
          end
        end

      assert "\n\n  Expected a keywords list as the first argument for `cereal`, got: `:not_a_list`." <>
               _ = message
    end

    test "should raise a compile-time error when the cereal is invalid" do
      %Breakfast.CompileError{message: message} =
        assert_raise Breakfast.CompileError, fn ->
          defmodule WillRaise do
            use Breakfast

            cereal []
          end
        end

      assert "Incomplete cereal definition, it's missing a `do` block." = message
    end

    test "should raise a compile-time error when field is given one or more invalid options" do
      %Breakfast.CompileError{message: message} =
        assert_raise Breakfast.CompileError, fn ->
          defmodule WillRaise do
            use Breakfast

            cereal do
              field :crazy, atom(), invalid_opt_1: :a, invalid_opt_2: :b
            end
          end
        end

      assert "\n\n  Invalid options given to `field`: :invalid_opt_1, :invalid_opt_2." <> _ =
               message
    end

    test "should raise a compile-time error when type is given one or more invalid options" do
      %Breakfast.CompileError{message: message} =
        assert_raise Breakfast.CompileError, fn ->
          defmodule WillRaise do
            use Breakfast

            cereal do
              type atom(), invalid_opt_1: :a, invalid_opt_2: :b
            end
          end
        end

      assert "\n\n  Invalid options given to `type`: :invalid_opt_1, :invalid_opt_2." <> _ =
               message
    end

    test "should raise a compile-time error when cereal is given one or more invalid options" do
      %Breakfast.CompileError{message: message} =
        assert_raise Breakfast.CompileError, fn ->
          defmodule WillRaise do
            use Breakfast

            cereal invalid_opt_1: :a, invalid_opt_2: :b do
            end
          end
        end

      assert "\n\n  Invalid options given to `cereal`: :invalid_opt_1, :invalid_opt_2." <> _ =
               message
    end

    test "should throw a compile error if invalid options were passed to a field" do
      error =
        assert_raise(Breakfast.CompileError, fn ->
          defmodule InvalidOptions do
            use Breakfast

            cereal do
              field :email, String.t(), default_value: ""
            end
          end
        end)

      assert error.message == """


               Invalid options given to `field`: :default_value.
               Allowed options are :fetch, :cast, :validate, :default.
             """
    end

    test "should throw a helpful error if a type could not be understood" do
      error =
        assert_raise(Breakfast.TypeError, fn ->
          defmodule BadType do
            use Breakfast

            cereal do
              field :vehicle, vehicle()
            end
          end
        end)

      assert error.message =~ "I couldn't understand the following type: vehicle()"
    end

    test "should throw a more specific error for a cyclical type" do
      error =
        assert_raise(Breakfast.TypeError, fn ->
          defmodule Cycle do
            use Breakfast

            cereal do
              field :value, Breakfast.TestDefinitions.cycle_a()
            end
          end
        end)

      assert error.message =~
               "It looks like the following type is a cyclical type: Breakfast.TestDefinitions.cycle_a()"
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

        def fetch_roles(params, :roles), do: Map.fetch(params, "UserRoles")
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

  describe "automatic type support" do
    defmodule LotsOfTypes do
      use Breakfast

      cereal fetch: &Map.fetch/2 do
        field(:any, any())
        field(:term, term())
        field(:atom, atom())
        field(:binary, binary())
        field(:boolean, boolean())
        field(:keyword, keyword())

        field(:typed_keyword, keyword(binary()))
        field(:map, map())
        field(:struct, struct())
        field(:tuple, tuple())
        field(:integer, integer())
        field(:float, float())
        field(:number, number())
        field(:neg_integer, neg_integer())
        field(:non_neg_integer, non_neg_integer())
        field(:pos_integer, pos_integer())
        field(:list, list())
        field(:nonempty_list, nonempty_list())
        field(:typed_list, list(atom()))
        field(:nonempty_typed_list, nonempty_list(atom()))
        field(:mfa, mfa())
        field(:module, module())
        field(:literal_atom, :hey)
        field(:literal_integer, 5)
        field(:literal_integer_in_range, 5..10)
        field(:literal_typed_list, [atom()])
        field(:literal_empty_list, [])
        field(:literal_nonempty_list, [...])
        field(:literal_typed_nonempty_list, [atom(), ...])
        field(:literal_keyword, format: atom())
        field(:literal_empty_map, %{})
        field(:literal_atom_key_map, %{format: atom()})

        field(:literal_required_option_key_map, %{
          required(binary()) => atom(),
          optional(atom()) => binary()
        })

        field(:literal_struct, %Breakfast.TestDefinitions.Struct{})
        field(:literal_typed_struct, %Breakfast.TestDefinitions.Struct{name: binary()})
        field(:literal_empty_tuple, {})
        field(:literal_typed_tuple, {atom(), binary(), integer()})
        field(:union_type, integer() | :never | :infinity)
        field(:remote, Breakfast.TestDefinitions.rgb_color())
      end
    end

    setup do
      valid_params = %{
        any: "this can be anything",
        term: "this can also be anything",
        atom: :cool,
        binary: "Very cool",
        boolean: true,
        keyword: [name: :cool],
        typed_keyword: [name: "Very cool"],
        map: %{"data" => %{"id" => 2}},
        struct: %Breakfast.TestDefinitions.Struct{name: :cool},
        tuple: {:apples, :oranges},
        integer: 9,
        float: 9.9,
        number: 1_000_000,
        neg_integer: -100,
        non_neg_integer: 0,
        pos_integer: 1,
        list: [],
        nonempty_list: [1, 2, 3],
        typed_list: [:apples, :oranges],
        nonempty_typed_list: [:apples, :oranges, :bananas],
        mfa: {Breakfast, :decode, 2},
        module: Breakfast,
        literal_atom: :hey,
        literal_integer: 5,
        literal_integer_in_range: 7,
        literal_typed_list: [:apples, :oranges],
        literal_empty_list: [],
        literal_nonempty_list: [1],
        literal_typed_nonempty_list: [:apples, :oranges, :bananas],
        literal_keyword: [format: :standard],
        literal_empty_map: %{},
        literal_atom_key_map: %{format: :standard},
        literal_required_option_key_map: %{
          "format" => :standard
        },
        literal_struct: %Breakfast.TestDefinitions.Struct{name: :cool},
        literal_typed_struct: %Breakfast.TestDefinitions.Struct{name: "Very cool"},
        literal_empty_tuple: {},
        literal_typed_tuple: {:apples, "oranges", 123},
        union_type: :never,
        remote: :green
      }

      invalid_params = %{
        any: "this will always succeed",
        term: "this will also always succeed",
        atom: "cool",
        binary: :very_cool,
        boolean: "true",
        keyword: %{name: :cool},
        typed_keyword: [name: 5],
        map: [],
        struct: %{name: :cool},
        tuple: [:apples, :oranges],
        integer: 0.0,
        float: 9,
        number: :five,
        neg_integer: 100,
        non_neg_integer: -100,
        pos_integer: 0,
        list: {},
        nonempty_list: [],
        typed_list: [:apples, "oranges"],
        nonempty_typed_list: [],
        mfa: {Breakfast, :decode, 2.0},
        module: "Breakfast",
        literal_atom: :apples,
        literal_integer: 6,
        literal_integer_in_range: 100,
        literal_typed_list: [:apples, "oranges"],
        literal_empty_list: [1],
        literal_nonempty_list: [],
        literal_typed_nonempty_list: [],
        literal_keyword: [format: "standard"],
        literal_empty_map: %{key: :value},
        literal_atom_key_map: %{format: "standard"},
        literal_required_option_key_map: %{
          format: :standard
        },
        literal_struct: %Breakfast.TestDefinitions.OtherStruct{email: ""},
        literal_typed_struct: %Breakfast.TestDefinitions.Struct{name: 42},
        literal_empty_tuple: {:apples},
        literal_typed_tuple: {"apples", "oranges", 123.56},
        union_type: :always,
        remote: :purple
      }

      %{valid_params: valid_params, invalid_params: invalid_params}
    end

    test "should be able to determine that a value is valid for all supported types", %{
      valid_params: params
    } do
      result = Breakfast.decode(LotsOfTypes, params)
      assert result.errors == []
    end

    test "should be able to determine that a value is invalid for all supported types", %{
      invalid_params: params
    } do
      result = Breakfast.decode(LotsOfTypes, params)

      assert result.errors ==
               [
                 atom: "expected a atom, got: \"cool\"",
                 binary: "expected a binary, got: :very_cool",
                 boolean: "expected a boolean, got: \"true\"",
                 keyword: "expected a keyword, got: %{name: :cool}",
                 typed_keyword:
                   "expected a keyword with values of type :binary, got: a keyword with invalid values: [name: [\"expected a binary, got: 5\"]]",
                 map: "expected a map, got: []",
                 struct: "expected a struct, got: %{name: :cool}",
                 tuple: "expected a tuple, got: [:apples, :oranges]",
                 integer: "expected a integer, got: 0.0",
                 float: "expected a float, got: 9",
                 number: "expected a number, got: :five",
                 neg_integer: "expected a neg_integer, got: 100",
                 non_neg_integer: "expected a non_neg_integer, got: -100",
                 pos_integer: "expected a pos_integer, got: 0",
                 list: "expected a list, got: {}",
                 nonempty_list: "expected a nonempty_list, got: []",
                 typed_list:
                   "expected a list of type :atom, got a list with at least one invalid element: expected a atom, got: \"oranges\"",
                 nonempty_typed_list: "expected a nonempty_list of type :atom, got: []",
                 mfa: "expected a mfa, got: {Breakfast, :decode, 2.0}",
                 module: "expected a module, got: \"Breakfast\"",
                 literal_atom: "expected :hey, got: :apples",
                 literal_integer: "expected 5, got: 6",
                 literal_integer_in_range: "expected an integer in 5..10, got: 100",
                 literal_typed_list:
                   "expected a list of type :atom, got a list with at least one invalid element: expected a atom, got: \"oranges\"",
                 literal_empty_list: "expected a empty_list, got: [1]",
                 literal_nonempty_list: "expected a nonempty_list of type :any, got: []",
                 literal_typed_nonempty_list: "expected a nonempty_list of type :atom, got: []",
                 literal_keyword:
                   "expected a keyword with values of type required(format: :atom), got: a keyword with invalid values: [format: [\"expected a atom, got: \\\"standard\\\"\"]]",
                 literal_empty_map: "expected a empty_map, got: %{key: :value}",
                 literal_atom_key_map:
                   "expected a field with key :format and value of type :atom, got: invalid value: [\"expected a atom, got: \\\"standard\\\"\"]",
                 literal_struct:
                   "expected a %Breakfast.TestDefinitions.Struct{}, got: %Breakfast.TestDefinitions.OtherStruct{email: \"\"}",
                 literal_typed_struct:
                   "expected a field with key :name and value of type :binary, got: invalid value: [\"expected a binary, got: 42\"]",
                 literal_empty_tuple: "expected {}, got: {:apples}",
                 literal_typed_tuple:
                   "expected {:atom, :binary, :integer}, got: {\"apples\", \"oranges\", 123.56}",
                 union_type: "expected one of :integer | :never | :infinity, got: :always",
                 remote: "expected one of :red | :green | :blue, got: :purple"
               ]
    end
  end
end
