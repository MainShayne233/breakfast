<p align="center">
  <img alt="Breakfast logo" width="350" src="https://raw.githubusercontent.com/MainShayne233/breakfast/master/logo-black.png">
</p>

[![Build Status](https://secure.travis-ci.org/MainShayne233/breakfast.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/breakfast)
[![Coverage Status](https://coveralls.io/repos/github/MainShayne233/breakfast/badge.svg?branch=master)](https://coveralls.io/github/MainShayne233/breakfast?branch=master)
[![Hex Version](http://img.shields.io/hexpm/v/breakfast.svg?style=flat)](https://hex.pm/packages/breakfast)

Breakfast is a decoder-generator library that:
- Has a consistent and declarative method for specifying the shape of your data
- Cuts down on boilerplate decoding code
- Leans on typespecs to determine how to validate data
- Provides clear error messages for invalid values
- Can be configured to decode any type of data

In other words: describe what your data looks like, and Breakfast will generate a decoder for it.

## Table of Contents

- [Use Case](#use-case)
- [Quick Start](#quick-start)
- [Using Your Types](#using-your-types)
- [Using the Result](#using-the-result)
- [Custom Configuration](#custom-configuration)
- [Required Fields and Default Values](#required-fields-and-default-values)
- [Embedded Cereals](#embedded-cereals)
- [Current State](#current-state)
- [Contributing](#contributing)


## Use Case

When dealing with some raw data, you might want to:
- Decode the data into a struct
- Validate that the types are what you expect them to be
- Have a typespec for your decoded data
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
  struct: %User{email: "john@aol.com", id: 1, roles: ["admin", "exec"]},
  fields: [%Breakfast.Field{name: :id}, %Breakfast.Field{name: :email}, %Breakfast.Field{name: :roles}]
}

iex> data = %{
...>   "id" => 1,
...>   "email" => "john@aol.com",
...>   "roles" => ["admin", :exec]
...> }
...> Breakfast.decode(User, data)
%Breakfast.Yogurt{
  errors: [roles: "expected a list of type binary(), got a list with at least one invalid element: expected a binary, got: :exec"],
  params: %{"email" => "john@aol.com", "id" => 1, "roles" => ["admin", :exec]},
  struct: %User{email: "john@aol.com", id: 1, roles: nil},
  fields: [%Breakfast.Field{name: :id}, %Breakfast.Field{name: :email}, %Breakfast.Field{name: :roles}]
}
```
<!--- MARKDOWN_TEST_END -->

## Quick Start

### Installing

Before you do anything, you need to add `:breakfast` as a dependency in your `mix.exs` file:

```elixir
# mix.exs

defp deps do
  [
    {:breakfast, "0.1.3"}
  ]
end
```

### Decoding with Breakfast

Let's say you're trying to decode some data of the following shape:

<!--- MARKDOWN_TEST_START -->
```elixir
%{
  "email" => "leo@aol.com",
  "age" => 67,
  "roles" => ["exec", "admin"]
}
```
<!--- MARKDOWN_TEST_END -->

First, we need to define a decoder that describes the shape of this data.

Breakfast's interface for describing the shape of your data is very similar to [Ecto's Schema definitions](https://hexdocs.pm/ecto/Ecto.Schema.html).

The primary difference between Breakfast and Ecto schemas is that Breakfast leans on [Elixir Typespecs](https://hexdocs.pm/elixir/typespecs.html) to declare your data's types.

Here is a simple example of describing the shape of the above data with Breakfast:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule User do
  use Breakfast

  cereal do
    field :email, String.t()
    field :age, non_neg_integer()
    field :roles, [String.t()]
  end
end
```
<!--- MARKDOWN_TEST_END -->

This decoder module is what Breakfast will use to decode and validate your data.

Once it's defined, you can pass this module along with the raw params to `Breakfast.decode/2`:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule User do
  use Breakfast

  cereal do
    field :email, String.t()
    field :age, non_neg_integer()
    field :roles, [String.t()]
  end
end

iex> data = %{
...>   "email" => "leo@aol.com",
...>   "age" => 67,
...>   "roles" => ["exec", "admin"]
...> }
...> Breakfast.decode(User, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"age" => 67, "email" => "leo@aol.com", "roles" => ["exec", "admin"]},
  struct: %User{age: 67, email: "leo@aol.com", roles: ["exec", "admin"]},
  fields: [%Breakfast.Field{name: :email}, %Breakfast.Field{name: :age}, %Breakfast.Field{name: :roles}]
}
```
<!--- MARKDOWN_TEST_END -->

That's it! Breakfast can decode basic data with little configuration, but can be told to do a lot more.

## Using Your Types

Beyond documenting your data, the typespecs for each field are also used to automatically determine how to validate that field.

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
  struct: %User{age: nil, name: "Sean"},
  fields: [%Breakfast.Field{name: :name}, %Breakfast.Field{name: :age}]
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
  struct: %Request{payload: %{"some" => "data"}, status: :success},
  fields: [%Breakfast.Field{name: :payload}, %Breakfast.Field{name: :status}]
}

iex> data = %{
...>   "payload" => %{"some" => "data"},
...>   "status" => :waiting
...> }
...> Breakfast.decode(Request, data)
%Breakfast.Yogurt{
  errors: [status: "expected one of :pending | :success | :failed, got: :waiting"],
  params: %{"payload" => %{"some" => "data"}, "status" => :waiting},
  struct: %Request{payload: %{"some" => "data"}, status: nil},
  fields: [%Breakfast.Field{name: :payload}, %Breakfast.Field{name: :status}]
}
```
<!--- MARKDOWN_TEST_END -->

Checkout the [types](./TYPES.md) docs for more on what types Breakfast supports.

## Using the Result

You might be asking, what's this `%Yogurt{}` thing?

A `%Yogurt{}` represents the result of a decoding. It contains four pieces of data:
- `params`: The original input params that you asked Breakfast to decode
- `errors`: A list of human-readable string errors that were accumulated when trying to decode the params
- `struct`: The decoded data that's been casted to the well-defined struct
- `fields`: The fields of the struct as a list of `Breakfast.Field`s

In your day-to-day programming, you can pattern match on a `%Yogurt{}` for control-flow, where an empty `:errors` list indicates that the decoding was successful:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule MathRequest do
  use Breakfast

  cereal do
    field :lhs, number()
    field :rhs, number()
    field :operation, :+ | :- | :* | :/, cast: :existing_atom_from_string
  end

  def existing_atom_from_string(value) do
    {:ok, String.to_existing_atom(value)}
  rescue _ in ArgumentError ->
    :error
  end
end

iex> request = %{"lhs" => 5.0, "rhs" => 2, "operation" => "/"}
...> case Breakfast.decode(MathRequest, request) do
...>   %Breakfast.Yogurt{errors: [], struct: result} -> {:ok, result}
...>   %Breakfast.Yogurt{errors: errors} -> {:error, errors}
...> end
{:ok, %MathRequest{lhs: 5.0, rhs: 2, operation: :/}}

iex> request = %{"lhs" => 5.0, "rhs" => 2, "operation" => "%"}
...> case Breakfast.decode(MathRequest, request) do
...>   %Breakfast.Yogurt{errors: [], struct: result} -> {:ok, result}
...>   %Breakfast.Yogurt{errors: errors} -> {:error, errors}
...> end
{:error, [operation: "expected one of :+ | :- | :* | :/, got: :%"]}
```
<!--- MARKDOWN_TEST_END -->

#### What about `:ok | :error` tuples?

We decided to not use `:ok | :error` tuples as the return type for the following reasons:
- We wanted to have a consistent type for the return value (it's always a `Yogurt.t()`, no matter what)
- There's a lot of context to return that you may or may not want to use (i.e. errors, input params, etc)
- You can still pattern match on any case that you care about handling in your code

## Custom Configuration

When Breakfast is decoding data, it runs through the same 3 steps for each field:
- `fetch`: Retrieve the field value from the data (i.e. `Map.fetch/2`)
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
  struct: %Settings{name: "Control Pannel", timeout: 1500, volume: 8},
  fields: [%Breakfast.Field{name: :name}, %Breakfast.Field{name: :timeout}, %Breakfast.Field{name: :volume}]
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
  struct: %Settings{name: nil, timeout: nil, volume: nil},
  fields: [%Breakfast.Field{name: :name}, %Breakfast.Field{name: :timeout}, %Breakfast.Field{name: :volume}]
}
```
<!--- MARKDOWN_TEST_END -->

You can also set the default behaviour for any of these steps:

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
  struct: %RGBColor{b: 30, g: 20, r: 10},
  fields: [%Breakfast.Field{name: :r}, %Breakfast.Field{name: :g}, %Breakfast.Field{name: :b}]
}

iex> data = %{"r" => "10", "G" => "Twenty", "B" => "500"}
...> Breakfast.decode(RGBColor, data)
%Breakfast.Yogurt{
  errors: [r: "value not found", g: "cast error", b: "expected an integer between 0 and 255, got: 500"],
  params: %{"B" => "500", "G" => "Twenty", "r" => "10"},
  struct: %RGBColor{b: nil, g: nil, r: nil},
  fields: [%Breakfast.Field{name: :r}, %Breakfast.Field{name: :g}, %Breakfast.Field{name: :b}]
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
  struct: %SpreadsheetRow{age: 37, email: "sully@aol.com", name: "Sully"},
  fields: [%Breakfast.Field{name: :name}, %Breakfast.Field{name: :age}, %Breakfast.Field{name: :email}]
}
```
<!--- MARKDOWN_TEST_END -->

## Required Fields and Default Values

By default, Breakfast considers every field to be a required field. The only way to make a field "optional" is to provide a `:default` value for that field:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule Post do
  use Breakfast

  cereal do
    field :title, String.t()
    field :content, String.t()
    field :tags, [String.t()], default: []
  end
end

iex> data = %{
...>  "title" => "Cool Thing I Did",
...>  "content" => "Thanks for reading!",
...> }
...> Breakfast.decode(Post, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"content" => "Thanks for reading!", "title" => "Cool Thing I Did"},
  struct: %Post{
    content: "Thanks for reading!",
    tags: [],
    title: "Cool Thing I Did"
  },
  fields: [%Breakfast.Field{name: :title}, %Breakfast.Field{name: :content}, %Breakfast.Field{name: :tags}]
}

iex> data = %{
...>  "title" => "Cool Thing I Did",
...>  "content" => "Thanks for reading!",
...>  "tags" => ["blockchain", "crypto"]
...> }
...> Breakfast.decode(Post, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"content" => "Thanks for reading!", "tags" => ["blockchain", "crypto"], "title" => "Cool Thing I Did"},
  struct: %Post{
    content: "Thanks for reading!",
    tags: ["blockchain", "crypto"],
    title: "Cool Thing I Did"
  },
  fields: [%Breakfast.Field{name: :title}, %Breakfast.Field{name: :content}, %Breakfast.Field{name: :tags}]
}
```
<!--- MARKDOWN_TEST_END -->

## Embedded Cereals

Breakfast allows you to use decoders within each other to describe the shape of nested data.

Here, the `Config` decoder is used as the type for the `User.config` field:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule Player do

  defmodule Config do
    use Breakfast

    cereal do
      field :timezone, String.t()
      field :sleep_timeout, non_neg_integer()
    end
  end

  use Breakfast

  cereal do
    field :name, String.t()
    field :score, integer()
    field :config, {:cereal, Config}
  end
end

iex> data = %{
...>   "name" => "Leo",
...>   "score" => 1600,
...>   "config" => %{
...>     "timezone" => "EST",
...>     "sleep_timeout" => 5000
...>   }
...> }
...> Breakfast.decode(Player, data)
%Breakfast.Yogurt{
  errors: [],
  params: %{"config" => %{"sleep_timeout" => 5000, "timezone" => "EST"}, "name" => "Leo", "score" => 1600},
  struct: %Player{
    name: "Leo",
    score: 1600,
    config: %Player.Config{
      sleep_timeout: 5000, timezone: "EST"
    }
  },
  fields: [%Breakfast.Field{name: :name}, %Breakfast.Field{name: :score}, %Breakfast.Field{name: :config}]
}

iex> data = %{
...>   "name" => "Leo",
...>   "score" => 1600,
...>   "config" => %{
...>     "timezone" => "EST",
...>     "sleep_timeout" => -5000
...>   }
...> }
...> Breakfast.decode(Player, data)
%Breakfast.Yogurt{
  errors: [config: [sleep_timeout: "expected a non_neg_integer, got: -5000"]],
  params: %{"config" => %{"sleep_timeout" => -5000, "timezone" => "EST"}, "name" => "Leo", "score" => 1600},
  struct: %Player{config: nil, name: "Leo", score: 1600},
  fields: [%Breakfast.Field{name: :name}, %Breakfast.Field{name: :score}, %Breakfast.Field{name: :config}]
}
```
<!--- MARKDOWN_TEST_END -->

## Current State

Breakfast `0.1` has been released! Further `v0.1.x` versions will include bug fixes, enhancements, etc.

Breakfast `0.2` development will include all new major features and breaking changes. Check out out the [roadmap](./ROADMAP/v0.2.md) to see what's coming/if you are looking to contribute!

## Contributing

Contributions are extremely welcome! This can take the form of pull requests and/or opening issues for bugs, feature requests, or general discussion.

If you want to make some changes but aren't sure where to begin, I'd be happy to help :).

I'd like to thank the following people who contributed to this project either via code and/or good ideas:
- [@evuez](https://github.com/evuez)
- [@GeoffreyPS](https://github.com/GeoffreyPS)
