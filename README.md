# Breakfast

[![Build Status](https://secure.travis-ci.org/MainShayne233/breakfast.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/breakfast)
[![Coverage Status](https://coveralls.io/repos/github/MainShayne233/breakfast/badge.svg?branch=master)](https://coveralls.io/github/MainShayne233/breakfast?branch=master)

Breakfast derives type-validating decoders from simple data specifications.

In other words: describe what your data looks like, and Breakfast will give you a decoder for it.

## Use Case

When dealing with some raw data, you might want to:
- Decode the data into a struct
- Validate that the field type are correct
- Have a type spec
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

With Breakfast, you can get the same (and more) with the following data spec definition:

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
  errors: [roles: "expected a binary, got: :exec"],
  params: %{"email" => "john@aol.com", "id" => 1, "roles" => ["admin", :exec]},
  struct: %User{email: "john@aol.com", id: 1, roles: nil}
}
```
<!--- MARKDOWN_TEST_END -->

Here, Breakfast is using the types specified in your data spec to determine how to validate each field.

## Current State

Development of `v0.1` is currently underyway! Checkout out the [roadmap](./ROADMAP/v0.1.md) to see what's comming/if you are looking to contribute!

## Contributing

Contributions are extremely welcome! This can take the form of pull requests and/or opening issues for bugs, feature requests, or general discussion.

If you want to make some changes but aren't sure where to begin, I'd be happy to help :).

I'd like to thank the following people who contributed to this project either via code and/or good ideas:
- [@evuez](https://github.com/evuez)
- [@GeoffreyPS](https://github.com/GeoffreyPS)
