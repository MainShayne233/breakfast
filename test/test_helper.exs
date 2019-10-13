defmodule TestHelper do
  @doc """
  Helpers for writing tests in this project.
  """

  defmacro testmodule(module_name, do: block) do
    quote do
      defmodule unquote(module_name) do
        use ExUnit.Case

        @describe_name __MODULE__
                       |> Module.split()
                       |> List.last()
                       |> to_string()
                       |> Macro.underscore()
                       |> String.replace("_", " ")

        describe @describe_name do
          unquote(block)
        end
      end
    end
  end
end

ExUnit.start()
