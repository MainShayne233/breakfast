# Breakfast

[![Build Status](https://secure.travis-ci.org/MainShayne233/breakfast.svg?branch=master "Build Status")](http://travis-ci.org/MainShayne233/breakfast)
[![Coverage Status](https://coveralls.io/repos/github/MainShayne233/breakfast/badge.svg?branch=master)](https://coveralls.io/github/MainShayne233/breakfast?branch=master)

Breakfast is a library for defining data decoders in a declarative, consistent, and succinct way.

## Goals

- Use an interface familiar to the Elixir community
  - Definition format closely resembles Ecto schema definitions [x]
  - Result type somewhat resembles an Ecto changeset [x]
- Use Elixir type specification syntax [x]
- Reduce boilerplate as much as possible
  - Default fetch, cast, and validation logic is derived from fields and their types [x]
  - Definitions are easily composable [x]
  - Automatic docs and typespecs produced [ ]
- Allow full custom control of decoding processes
  - Fetch, cast, and validate procedures can be defined at the definition level, as well as the field level separately [x]
- Decode failures result in clear errors pointing at what was wrong with the data [x]
- Helpful error messages [ ]

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
