# Breakfast

[![Build Status](https://secure.travis-ci.org/MainShayne233/breakfast.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/breakfast)
[![Coverage Status](https://coveralls.io/repos/github/MainShayne233/breakfast/badge.svg?branch=master)](https://coveralls.io/github/MainShayne233/breakfast?branch=master)

Breakfast is a decoder-generator library that:
- Has a consistent and declarative method for specifying the shape of your data
- Cuts down on boilerplate decoding code
- Leans on type specs to determine how to validate data
- Provides clear error messages for invalid values
- Can be configured to decode any type of data

In other words: describe what your data looks like, and Breakfast will generate a decoder for it.

## Use Case

When dealing with some raw data, you might want to:
- Decode the data into a struct
- Validate that the types are what you expect them to be
- Have a type spec for your decoded data
- etc

In Elixir, you might write the following to accomplish this:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule User do
  @type t :: %__MODULE__{
          id: integer(),
          email: String.t(),
          roles: [String.t()]
        }

  @enforce_keys [:id, :email, :roles]

  defstruct @enforce_keys

  def decode(params) do
    with id when is_integer(id) <- params["id"],
         email when is_binary(email) <- params["email"],
         roles when is_list(roles) <- params["roles"],
         true <- Enum.all?(roles, &is_binary/1) do
      {:ok, %__MODULE__{id: id, email: email, roles: roles}}
    else
      _ ->
        :error
    end
  end
end

iex> data = %{
...>   "id" => 1,
...>   "email" => "john@aol.com",
...>   "roles" => ["admin", "exec"]
...> }
...> User.decode(data)
{:ok, %User{id: 1, email: "john@aol.com", roles: ["admin", "exec"]}}

iex> data = %{
...>   "id" => 1,
...>   "email" => "john@aol.com",
...>   "roles" => ["admin", :exec]
...> }
...> User.decode(data)
:error
```
<!--- MARKDOWN_TEST_END -->

With Breakfast, you can get the same (and more) just by describing what your data should look like:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule User do
  use Breakfast

  cereal do
    field :id, integer()
    field :email, String.t()
    field :roles, [String.t()]
  end
end

iex> data = %{
...>   "id" => 1,
...>   "email" => "john@aol.com",
...>   "roles" => ["admin", "exec"]
...> }
...> Breakfast.decode(User, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"email" => "john@aol.com", "id" => 1, "roles" => ["admin", "exec"]},
  struct: %User{email: "john@aol.com", id: 1, roles: ["admin", "exec"]}
}

iex> data = %{
...>   "id" => 1,
...>   "email" => "john@aol.com",
...>   "roles" => ["admin", :exec]
...> }
...> Breakfast.decode(User, data)
%Breakfast.Yogurt{
  errors: [roles: "expected a list of type :binary, got a list with at least one invalid element: expected a binary, got: :exec"],
  params: %{"email" => "john@aol.com", "id" => 1, "roles" => ["admin", :exec]},
  struct: %User{email: "john@aol.com", id: 1, roles: nil}
}
```
<!--- MARKDOWN_TEST_END -->

## Defining Data

Breakfast's interface for describing the shape of your data is very similar to [Ecto's Schema definitions](https://hexdocs.pm/ecto/Ecto.Schema.html).

The primary difference between Breakfast and Ecto schemas is that Breakfast leans on [Elixir Typespecs](https://hexdocs.pm/elixir/typespecs.html) to declare your data's types.

Here is a simple example of describing data using Breakfast:

<!--- MARKDOWN_TEST_START -->
``` elixir
defmodule User do
  use Breakfast

  cereal do
    field :name, String.t()
    field :age, non_neg_integer()
  end
end

iex> data = %{
...>   "name" => "Sean",
...>   "age" => 45
...> }
...> Breakfast.decode(User, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"age" => 45, "name" => "Sean"},
  struct: %User{age: 45, name: "Sean"}
}
```
<!--- MARKDOWN_TEST_END -->

## Using Your Types

Beyond documenting your data, the type specs for each field are also used to automatically determine how to validate that field.

In the following example, we can see that a field of type `non_neg_integer()` will not accept a value < 0:

<!--- MARKDOWN_TEST_START -->
``` elixir
defmodule User do
  use Breakfast

  cereal do
    field :name, String.t()
    field :age, non_neg_integer()
  end
end

iex> data = %{
...>   "name" => "Sean",
...>   "age" => -5
...> }
...> Breakfast.decode(User, data)
%Breakfast.Yogurt{
  errors: [age: "expected a non_neg_integer, got: -5"],
  params: %{"age" => -5, "name" => "Sean"},
  struct: %User{age: nil, name: "Sean"}
}
```
<!--- MARKDOWN_TEST_END -->

Breakfast can even handle more complex types, such as unions:

<!--- MARKDOWN_TEST_START -->
``` elixir
defmodule Request do
  use Breakfast

  cereal do
    field :payload, map()
    field :status, :pending | :success | :failed
  end
end

iex> data = %{
...>   "payload" => %{"some" => "data"},
...>   "status" => :success
...> }
...> Breakfast.decode(Request, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"payload" => %{"some" => "data"}, "status" => :success},
  struct: %Request{payload: %{"some" => "data"}, status: :success}
}

iex> data = %{
...>   "payload" => %{"some" => "data"},
...>   "status" => :waiting
...> }
...> Breakfast.decode(Request, data)
%Breakfast.Yogurt{
  errors: [status: "expected one of :pending | :success | :failed, got: :waiting"],
  params: %{"payload" => %{"some" => "data"}, "status" => :waiting},
  struct: %Request{payload: %{"some" => "data"}, status: nil}
}
```
<!--- MARKDOWN_TEST_END -->

Checkout the [types](./TYPES.md) docs for more on what types Breakfast supports.

## Custom Configuration

When Breakfast is decoding data, it runs through the same 3 steps for each field:
- `fetch`: Retreieve the field value from the data (i.e. `Map.fetch/2`)
- `cast`: Map the field value from one value to another, if necessary (i.e. `Integer.parse/1`)
- `validate`: Check to see if the field value is valid (i.e. `is_binary/1`)

Out of the box, Breakfast will assume the following for each step:
- `fetch`: The raw data is in the form of a string-keyed map, and the key for the field is the string version of the declared field name
- `cast`: No casting is necessary
- `validate`: Ensure that the value matches the field type

However, each of these steps can be customized for any field:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule Settings do
  use Breakfast

  cereal do
    field(:name, String.t(), fetch: :fetch_name)
    field(:timeout, integer(), cast: :int_from_string)
    field(:volume, integer(), validate: :valid_volume)
  end

  def fetch_name(params, :name) do
    Map.fetch(params, "SettingsName")
  end

  def int_from_string(value) do
    with true <- is_binary(value),
         {int, ""} <- Integer.parse(value) do
      {:ok, int}
    else
      _ ->
        :error
    end
  end

  def valid_volume(volume) when volume in 0..100, do: []
  def valid_volume(volume), do: ["expected an integer in 0..100, got: #{inspect(volume)}"]
end

iex> data = %{
...>   "SettingsName" => "Control Pannel",
...>   "timeout" => "1500",
...>   "volume" => 8
...> }
...> Breakfast.decode(Settings, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"SettingsName" => "Control Pannel", "timeout" => "1500", "volume" => 8},
  struct: %Settings{name: "Control Pannel", timeout: 1500, volume: 8}
}

iex> data = %{
...>   "name" => "Control Pannel",
...>   "timeout" => 1500,
...>   "volume" => -100
...> }
...> Breakfast.decode(Settings, data)
%Breakfast.Yogurt{
  errors: [name: "value not found", timeout: "cast error", volume: "expected an integer in 0..100, got: -100"],
  params: %{"name" => "Control Pannel", "timeout" => 1500, "volume" => -100},
  struct: %Settings{name: nil, timeout: nil, volume: nil}
}
```
<!--- MARKDOWN_TEST_END -->

You can also set the default behavior for any of these steps:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule RGBColor do
  use Breakfast

  cereal fetch: :fetch_upcase_key, cast: :int_from_string, validate: :valid_rgb_value do
    field :r, integer()
    field :g, integer()
    field :b, integer()
  end

  def fetch_upcase_key(params, field) do
    key =
      field
      |> to_string()
      |> String.upcase()
    
    Map.fetch(params, key)
  end

  def int_from_string(value) do
    with true <- is_binary(value),
         {int, ""} <- Integer.parse(value) do
      {:ok, int}
    else
      _ ->
        :error
    end
  end

  def valid_rgb_value(value) when value in 0..255, do: []

  def valid_rgb_value(value),
    do: ["expected an integer between 0 and 255, got: #{inspect(value)}"]
end

iex> data = %{"R" => "10", "G" => "20", "B" => "30"}
...> Breakfast.decode(RGBColor, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"B" => "30", "G" => "20", "R" => "10"},
  struct: %RGBColor{b: 30, g: 20, r: 10}
}

iex> data = %{"r" => "10", "G" => "Twenty", "B" => "500"}
...> Breakfast.decode(RGBColor, data)
%Breakfast.Yogurt{
  errors: [r: "value not found", g: "cast error", b: "expected an integer between 0 and 255, got: 500"],
  params: %{"B" => "500", "G" => "Twenty", "r" => "10"},
  struct: %RGBColor{b: nil, g: nil, r: nil}
}
```
<!--- MARKDOWN_TEST_END -->

Given this, Breakfast can actually decode any form of data, not just maps:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule SpreadsheetRow do
  use Breakfast

  @column_indices %{
    name: 0,
    age: 1,
    email: 2
  }

  cereal fetch: :fetch_at_list_index do
    field :name, String.t()
    field :age, non_neg_integer()
    field :email, String.t()
  end

  def fetch_at_list_index(data, field_name) do
    index = Map.fetch!(@column_indices, field_name)
    Enum.fetch(data, index)
  end
end

iex> data = ["Sully", 37, "sully@aol.com"]
...> Breakfast.decode(SpreadsheetRow, data)
%Breakfast.Yogurt{
  errors: [],
  params: ["Sully", 37, "sully@aol.com"],
  struct: %SpreadsheetRow{age: 37, email: "sully@aol.com", name: "Sully"}
}
```
<!--- MARKDOWN_TEST_END -->

## Current State

Development of `v0.1` is currently underyway! Checkout out the [roadmap](./ROADMAP/v0.1.md) to see what's comming/if you are looking to contribute!

## Contributing

Contributions are extremely welcome! This can take the form of pull requests and/or opening issues for bugs, feature requests, or general discussion.

If you want to make some changes but aren't sure where to begin, I'd be happy to help :).

I'd like to thank the following people who contributed to this project either via code and/or good ideas:
- [@evuez](https://github.com/evuez)
- [@GeoffreyPS](https://github.com/GeoffreyPS)
