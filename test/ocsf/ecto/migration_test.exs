defmodule OCSF.Ecto.MigrationTest do
  use ExUnit.Case, async: true

  alias OCSF.Ecto.Migration

  doctest OCSF.Ecto.Migration

  describe "current_version/0" do
    test "returns a positive integer" do
      assert Migration.current_version() >= 1
    end

    test "matches the length of versions/0" do
      assert Migration.current_version() == length(Migration.versions())
    end
  end

  describe "versions/0" do
    test "returns a dense list starting at 1" do
      versions = Migration.versions()

      assert List.first(versions) == 1
      assert versions == Enum.to_list(1..Migration.current_version())
    end
  end

  describe "up/1 argument validation" do
    test "raises on a non-integer version" do
      assert_raise ArgumentError, ~r/invalid :version/, fn ->
        Migration.up(version: :latest)
      end
    end

    test "raises on version 0" do
      assert_raise ArgumentError, ~r/invalid :version/, fn ->
        Migration.up(version: 0)
      end
    end

    test "raises on a version above current" do
      too_high = Migration.current_version() + 1

      assert_raise ArgumentError, ~r/invalid :version/, fn ->
        Migration.up(version: too_high)
      end
    end

    test "raises when :prefix is overridden" do
      assert_raise ArgumentError, ~r/not supported yet/, fn ->
        Migration.up(prefix: "custom__")
      end
    end

    test "raises when :table is overridden" do
      assert_raise ArgumentError, ~r/not supported yet/, fn ->
        Migration.up(table: "events")
      end
    end

    test "raises when :schema is provided" do
      assert_raise ArgumentError, ~r/not supported yet/, fn ->
        Migration.up(schema: "analytics")
      end
    end
  end

  describe "down/1 argument validation" do
    test "raises on an unknown version" do
      assert_raise ArgumentError, ~r/invalid :version/, fn ->
        Migration.down(version: 99)
      end
    end

    test "raises on override options" do
      assert_raise ArgumentError, ~r/not supported yet/, fn ->
        Migration.down(table: "events")
      end
    end
  end
end
