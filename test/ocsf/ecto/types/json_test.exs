defmodule OCSF.Ecto.Types.JsonTest do
  use ExUnit.Case, async: true

  alias OCSF.Ecto.Types.Json

  describe "type/0" do
    test "maps to the :map (jsonb) column type" do
      assert Json.type() == :map
    end
  end

  describe "cast/1" do
    test "accepts a JSON object unchanged" do
      object = %{"uid" => "role-1", "name" => "admin"}
      assert {:ok, ^object} = Json.cast(object)
    end

    test "accepts a JSON array unchanged" do
      list = [%{"uid" => "g-1"}, %{"uid" => "g-2"}]
      assert {:ok, ^list} = Json.cast(list)
    end
  end

  describe "load/1 and dump/1" do
    test "round-trip an object verbatim" do
      object = %{"name" => "api", "version" => "v1"}
      assert {:ok, ^object} = Json.dump(object)
      assert {:ok, ^object} = Json.load(object)
    end

    test "round-trip a list verbatim" do
      list = ["profile_a", "profile_b"]
      assert {:ok, ^list} = Json.dump(list)
      assert {:ok, ^list} = Json.load(list)
    end
  end

  describe "embed_as/1" do
    test "keeps the value as-is when embedded" do
      assert Json.embed_as(:json) == :self
    end
  end
end
