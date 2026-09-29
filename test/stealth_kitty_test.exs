defmodule StealthKittyTest do
  use ExUnit.Case, async: false

  test "loads the configured token and permits an explicit override" do
    previous = Application.get_env(:stealth_kitty, :access_token)
    Application.put_env(:stealth_kitty, :access_token, "configured")

    on_exit(fn ->
      Application.put_env(:stealth_kitty, :access_token, previous)
    end)

    assert StealthKitty.new().access_token == "configured"
    assert StealthKitty.new(access_token: "explicit").access_token == "explicit"
    assert StealthKitty.new(access_token: nil).access_token == nil
  end

  test "rejects invalid request options before contacting Lumo" do
    client = StealthKitty.new()

    assert {:error, :empty_prompt} = StealthKitty.ask(client, "   ")

    assert {:error, :invalid_tools} =
             StealthKitty.ask(client, "Hi", tools: ["bad"])

    assert {:error, :invalid_model} =
             StealthKitty.ask(client, "Hi", model: "bad")

    assert {:error, :invalid_reasoning_effort} =
             StealthKitty.ask(client, "Hi", reasoning_effort: "bad")
  end

  test "loads model and web search defaults with explicit overrides" do
    model = Application.get_env(:stealth_kitty, :model)
    effort = Application.get_env(:stealth_kitty, :reasoning_effort)
    web_search = Application.get_env(:stealth_kitty, :web_search)
    Application.put_env(:stealth_kitty, :model, "lumo-max")
    Application.put_env(:stealth_kitty, :reasoning_effort, "high")
    Application.put_env(:stealth_kitty, :web_search, true)

    on_exit(fn ->
      Application.put_env(:stealth_kitty, :model, model)
      Application.put_env(:stealth_kitty, :reasoning_effort, effort)
      Application.put_env(:stealth_kitty, :web_search, web_search)
    end)

    client = StealthKitty.new()
    assert client.model == "lumo-max"
    assert client.reasoning_effort == "high"
    assert client.web_search

    client =
      StealthKitty.new(
        model: "lumo-lite",
        reasoning_effort: "none",
        web_search: false
      )

    assert client.model == "lumo-lite"
    assert client.reasoning_effort == "none"
    refute client.web_search
  end
end
