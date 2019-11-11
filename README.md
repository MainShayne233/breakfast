# Breakfast

[![Build Status](https://secure.travis-ci.org/MainShayne233/breakfast.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/breakfast)
[![Coverage Status](https://coveralls.io/repos/github/MainShayne233/breakfast/badge.svg?branch=master)](https://coveralls.io/github/MainShayne233/breakfast?branch=master)

Breakfast is a library for defining data decoders in a declarative, consistent, and succinct way.

## Examples

Out of the box `Breakfast` supports decoding plain Elixir maps with string, snake_case keys with no configuration:

```elixir
params = %{
  "email" => "my@email.com",
  "age" => 20,
  "roles" => ["user", "exec"]
}

defmodule User do
  use Breakfast

  cereal do
    field :email, String.t()
    field :age, integer()
    field :roles, [String.t()]
  end
end


iex> Breakfast.decode(User, params)
%Breakfast.Yogurt{
  errors: [],
  params: %{"age" => 20, "email" => "my@email.com", "roles" => ["user", "exec"]},
  struct: %User{age: 20, email: "my@email.com", roles: ["user", "exec"]}
}

iex> Breakfast.decode(User, %{params | "age" => 20.5})
%Breakfast.Yogurt{
  errors: [age: "expected a integer, got: 20.5"],
  params: %{
    "age" => 20.5,
    "email" => "my@email.com",
    "roles" => ["user", "exec"]
  },
  struct: %User{age: nil, email: "my@email.com", roles: ["user", "exec"]}
}
```
