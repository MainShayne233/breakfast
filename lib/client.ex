defmodule Client do
  use Vlad

  defdata SingleField do
    field(:id, :string)
  end

  defdata MultiField do
    field(:id, :string)
    field(:email, :string)
    field(:roles, {:array, :string}, default: [])
    field(:parent_id, :string, default: nil)
    field(:details, :map)
    field(:config, Config)

    defdata Config do
      field(:retries, :integer, default: 0)
      field(:port, :integer, cast: &Client.int_from_string/1)
    end
  end

  def int_from_string(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> {:ok, int}
      _other -> :error
    end
  end

  def int_from_string(_), do: :error
end
