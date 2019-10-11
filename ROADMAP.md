# Roadmap

---

## `defdecoder/2`

This is the macro used to define a decoder.

### Acceptance Criteria:

#### General:
- Defines a module to house the autogenerated code ✅
- Module gets a `@moduledoc` ❌
- Defines a struct that represents the decoded result ✅
- The struct uses `@enforce_keys` for fields not given an explicit `:default` ✅
- The struct gets a `@type t` generated for it ✅
- The struct gets a `@typedoc` generated for it ❌
- Defaults to using `&Map.fetch(&1, to_string(field_name))` as the default parser ✅
- Allows for a `:default_parse` function to be defined ❌
]'
#### Compile Errors:
- If a field uses a type and we cannot determine what validate function to use for it, raise an error explaining this and how to solve it ✅

---

## `defdecoder -> field/3`

This is a "virtual" function used inside a `defdecoder` that allows for defining a field on a decoder.

### Acceptance Criteria:

#### General
- Takes a name and type as the first two arguments ✅
- Allows for a `:default` option that will be used if the parse function returns `:error` ✅
- Allows for a `:parse` option that's value will be used as the field's parse function ✅
- Allows for a `:cast` option that's value will be used as the field's cast function ❓
- Allows for a `:validate` option that's value will be used as the field's validate function ❓
---

## `defdecoder -> defdecoder/2`

This is a "virtual" function that allows for nested decoders to be defined within a decoder.

### Acceptance Criteria:

#### General
- Should be compiled and namespaced within the parent decoder ✅
- Should compile and behave exactly like a normal decoder ✅

---

## `decode/1`

This function's interface looks like: `decode(value :: term()) -> {:ok, t()} | {:error, Breakfast.DecodeError.t()}`

### Acceptance Criteria:

#### General:
- Module gets defined to house the decoded result struct ✅
- Gets `@doc` ❌
- Gets `@spec` ❌

#### Decode Errors:
- If a field parse function returns `:error`, return a parse error w/ name of field ✅
- If a field cast function returns `:error`, return a cast error w/ name of field and value that failed to cast ✅
- If a field validate function returns `:error`, return a validate error w/ name of field and value that failed the validation ✅
- If a custom parse function returns an invalid type, raise an exception stating the field name and the reason why ✅
- If a custom cast function returns an invalid type, raise an exception stating the field name and the reason why ❓
- If a custom validate function returns an invalid type, raise an exception stating the field name and the reason why ❓