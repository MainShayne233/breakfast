defmodule VladTest do
  use ExUnit.Case
  doctest Vlad

  test "greets the world" do
    assert Vlad.hello() == :world
  end
end
