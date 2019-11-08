defmodule User do
  use Breakfast

  @type url() :: String.t()
  @type email() :: String.t()

  # cereal fetch: ..., cast: ..., validate: ...
  cereal fetch: &Breakfast.Fetch.atom/2 do
    # use User.A, only: []

    field :name, String.t(), validate: :no_error
    field :email, email(), cast: :identity
    field :website, url()
    field :tags, [String.t()]

    type email(), validate: :validate_email

    type url(),
      cast: :cast_url,
      validate: {:validate_url, https_only: true}
  end

  def cast_url(url), do: {:ok, URI.parse(url)}

  def validate_email(value) do
    if value =~ "@" do
      []
    else
      ["Missing @ in email"]
    end
  end

  def validate_url(%URI{scheme: "https"}, https_only: true), do: []
  def validate_url(%URI{}, https_only: true), do: ["invalid scheme"]
  def validate_url(%URI{}, _opts), do: []

  def no_error(_), do: []
  def identity(x), do: {:ok, x}
end

defmodule Request do
  use Breakfast

  @type status :: :approved | :pending | :rejected

  cereal do
    field :status, status()

    type status(), validate: :validate_status, cast: :cast_status
  end

  def cast_status("approved"), do: {:ok, :approved}
  def cast_status("pending"), do: {:ok, :pending}
  def cast_status("rejected"), do: {:ok, :rejected}
  def cast_status(_other), do: :error

  def validate_status(status) do
    if status in [:approved, :pending, :rejected] do
      []
    else
      ["status should be :approved, :pending or :rejected, got #{inspect(status)}"]
    end
  end
end

defmodule JSUser do
  use Breakfast

  cereal fetch: :camel_key_fetch do
    field :first_name, String.t()
    field :last_name, String.t()
    field :age, integer(), fetch: :fetch_age
  end

  def fetch_age(%{"UserAge" => age}, _key), do: {:ok, age}
  def fetch_age(_, _), do: :error

  def camel_key_fetch(params, key) do
    {first_char, rest} = key |> to_string() |> Macro.camelize() |> String.split_at(1)
    camel_key = String.downcase(first_char) <> rest
    Map.fetch(params, camel_key)
  end
end

defmodule Nested do
  defmodule A do
    use Breakfast

    cereal do
      field :b, Nested.B.t()

      # embed :b, Nested.B.t()

      type Nested.B.t(), cast: :cast_b, validate: :validate_b
    end

    def validate_b(%Breakfast.Yogurt{errors: []}), do: []
    def validate_b(%Breakfast.Yogurt{errors: errors}), do: errors

    def validate_b(%{}), do: []
    def validate_b(errors) when is_list(errors), do: errors

    # def cast_b(%{} = params), do: {:ok, Breakfast.decode(Nested.B, params)}

    def cast_b(%{} = params) do
      case Breakfast.decode(Nested.B, params) do
        %Breakfast.Yogurt{errors: [], struct: struct} -> {:ok, struct}
        %Breakfast.Yogurt{errors: errors} -> {:ok, errors}
      end
    end
  end

  defmodule B do
    use Breakfast

    @type t() :: %{}

    cereal do
      # field :c, C.t()
      field :my_value, integer()
    end
  end

  #  defmodule C do
  #    use Breakfast
  #
  #    @type t() :: %{}
  #
  #    cereal do
  #      field :value, integer()
  #    end
  #  end
end
