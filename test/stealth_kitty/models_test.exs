defmodule StealthKitty.ModelsTest do
  use ExUnit.Case, async: true

  alias StealthKitty.{AnswerMode, Models}

  test "cycles through models shown in the web client" do
    assert Models.next("apertus-15") == "lumo-lite"
    assert Models.next("lumo-lite") == "lumo-max"
    assert Models.next("lumo-max") == "apertus-15"
    assert Models.valid?("apertus-15")
    refute Models.valid?("unknown")
  end

  test "toggles fast and thinking modes" do
    assert AnswerMode.toggle("none") == "high"
    assert AnswerMode.toggle("high") == "none"
    assert AnswerMode.valid?("high")
    refute AnswerMode.valid?("low")
  end
end
