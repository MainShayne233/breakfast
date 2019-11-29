# Types

When defining a decoder in Breakfast, we use [Elixir Typespecs](https://hexdocs.pm/elixir/typespecs.html) to declare the types for each field.

Breakfast aims to be type aware. By type aware we mean that Breakfast knows how to validate if a value is in fact a `String.t()`, `non_neg_integer()`, `list(atom())`, etc.

The following are the types that Breakfast has formal support for:

  - Basic Types:
    - `any()`
    - `term()`
    - `atom()`
    - `map()`
    - `struct()`
    - `tuple()`
    - `float()`
    - `integer()`
    - `neg_integer()`
    - `non_neg_integer()`
    - `pos_integer()`
    - `list(type)`
    - `nonempty_list(type)`
  - Literals:
    - Atoms (`:red`, `:blue`)
    - Integers (`1`, `1..10`)
    - Lists (`[type]`, `[]`, `[...]`, `[type, ...]`, `[key: value_type]`)
    - Maps (`%{}`, `%{key: value_type}`, `%{required(key_type) => value_type}`, `%{optional(key_type) => value_type}`, `%Struct{}`, `%Struct{key: value_type}`)
    - Tuples (`{}`, `{type1, type2, ... typeN}`)
  - Built-in Types:
    - `term()`
    - `binary()`
    - `boolean()`
    - `keyword()`
    - `keyword(t)`
    - `list()`
    - `nonempty_list()`
    - `mfa()`
    - `module()`
    - `number()`
  - Union Types (`:red | :blue | :green`, `String.t() | atom()`)
  - Remote Types that resolve to a supported type
  - Other Breakfast decoders `{:cereal, Config}`

### Note about remote types

Elixir allows for [remote type](https://hexdocs.pm/elixir/typespecs.html#remote-types) definitions (i.e. custom types).

Elixir has many built-in remote types, like `String.t()`. Most of these remote types can be resolved to more basic Elixir types. In the case of `String.t()`, it resolves to `binary()` (at least at in Elixir 1.9).

If a built-in remote type can be resolved to a type Breakfast can understand, it can handle that remote type no problem. Breakfast can handle many built-in remote types, but there are a few more complex ones that it cannot. Improving this type support would be a great contribution! :-)

Breakfast should also be able to handle most [User-Defined Types](https://hexdocs.pm/elixir/typespecs.html#user-defined-types), which are just remote types that you defined yourself. Breakfast can only understand a user-defined type if the module where that type was defined was compiled before Breakfast tries to understand it.

If defined like so, Breakfast will fail to understand the type `color()` given the compile time constraint:

```elixir
defmodule Texture do
  use Breakfast

  @type color :: :red | :green | :blue

  cereal do
    field :color, color()
  end
end
```

One way to ensure that the user-defined type will be available for Breakfast's use is to define the type is defined in its own module:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule Texture do
  use Breakfast

  defmodule Types do
    @type color :: :red | :green | :blue
  end

  cereal do
    field :color, Types.color()
  end
end
```
<!--- MARKDOWN_TEST_END -->

If using a type from a module outside of your decoder module, you can `require` the type module to ensure it's compiled in time:

<!--- MARKDOWN_TEST_START -->
```elixir
# in lib/types.ex
defmodule Types do
  @type color :: :red | :green | :blue
end


# in lib/texture.ex
defmodule Texture do
  use Breakfast

  require Types

  cereal do
    field :color, Types.color()
  end
end
```
<!--- MARKDOWN_TEST_END -->


### Note about cyclical types

Elixir allows you to define cyclical types (types that refer to theirselves recursively). Here is an example:

<!--- MARKDOWN_TEST_START -->
```elixir
defmodule Cycle do
  @type a :: b()
  @type b :: a()
end
```
<!--- MARKDOWN_TEST_END -->

If we tries to resolve the type `Cycle.a()`, we'd see that it points to `Cycle.b()`, which points back to `Cycle.a()`, and so on.

There's not much Breakfast can do in this case, and so using cyclical types is not allowed.
