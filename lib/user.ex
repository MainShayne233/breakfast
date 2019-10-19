defmodule User do
  use Breakfast

  @type url() :: String.t()
  @type email() :: String.t()

  # cereal fetch: ..., cast: ..., validate: ...
  cereal fetch: &Breakfast.Fetch.atom/2 do
    # using MyTypes

    field(:name, String.t(), validate: :no_error)
    field(:email, email(), cast: :identity)
    field(:website, url())

    type(email(), validate: :validate_email)

    type(url(),
      cast: :cast_url,
      validate: {:validate_url, https_only: true}
    )
  end

  def cast_url(url), do: {:ok, URI.parse(url)}

  def validate_email(value) do
    if value =~ "@" do
      []
    else
      ["Missing @ in email"]
    end
  end

  def validate_url("https://" <> _, https_only: true), do: []
  def validate_url(_value, https_only: true), do: ["Invalid scheme"]
  def validate_url(_value, _opts), do: []

  def no_error(_), do: []
  def identity(x), do: {:ok, x}
end
