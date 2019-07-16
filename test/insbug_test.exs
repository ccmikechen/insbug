defmodule InsbugTest do
  use ExUnit.Case
  doctest Insbug

  test "greets the world" do
    assert Insbug.hello() == :world
  end
end
