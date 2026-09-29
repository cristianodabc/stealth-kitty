defmodule StealthKitty.Models do
  @moduledoc "Names and selection order for Lumo models."

  @models ["apertus-15", "lumo-lite", "lumo-max"]

  @doc "Checks whether Lumo accepts a model identifier."
  @spec valid?(binary()) :: boolean()
  def valid?(model) do
    model in @models
  end

  @doc "Returns the next model in the terminal selector."
  @spec next(binary()) :: binary()
  def next("apertus-15") do
    "lumo-lite"
  end

  def next("lumo-lite") do
    "lumo-max"
  end

  def next(_model) do
    "apertus-15"
  end

  @doc "Returns a short name suitable for the terminal."
  @spec label(binary()) :: binary()
  def label("apertus-15") do
    "Apertus 1.5"
  end

  def label("lumo-max") do
    "Lumo 2.0 Max"
  end

  def label(_model) do
    "Lumo 2.0 Lite"
  end
end
