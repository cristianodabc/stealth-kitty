defmodule LumexTest do
  use ExUnit.Case, async: false

  test "loads the configured token and permits an explicit override" do
    previous = Application.get_env(:lumex, :access_token)
    Application.put_env(:lumex, :access_token, "configured")

    on_exit(fn ->
      Application.put_env(:lumex, :access_token, previous)
    end)

    assert Lumex.new().access_token == "configured"
    assert Lumex.new(access_token: "explicit").access_token == "explicit"
    assert Lumex.new(access_token: nil).access_token == nil
  end

  test "rejects invalid request options before contacting Lumo" do
    client = Lumex.new()

    assert {:error, :empty_prompt} = Lumex.ask(client, "   ")
    assert {:error, :invalid_tools} = Lumex.ask(client, "Hi", tools: ["bad"])
    assert {:error, :invalid_model} = Lumex.ask(client, "Hi", model: "bad")
  end
end
