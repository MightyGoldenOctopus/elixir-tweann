defmodule TweannTest do
  use ExUnit.Case
  doctest Tweann

  test "greets the world" do
    assert Tweann.hello() == :world
  end
end
