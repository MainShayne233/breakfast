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

In Elixir, you might write the following to accomplish those goals:

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

## Current State

Development of `v0.1` is currently underyway! Checkout out the [roadmap](./ROADMAP/v0.1.md) to see what's comming/if you are looking to contribute!

## Contributing

Contributions are extremely welcome! This can take the form of pull requests and/or opening issues for bugs, feature requests, or general discussion.

If you want to make some changes but aren't sure where to begin, I'd be happy to help :).

I'd like to thank the following people who contributed to this project either via code and/or good ideas:
- [@evuez](https://github.com/evuez)
- [@GeoffreyPS](https://github.com/GeoffreyPS)
