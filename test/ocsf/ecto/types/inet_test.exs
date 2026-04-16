defmodule OCSF.Ecto.Types.InetTest do
  use ExUnit.Case, async: true

  alias OCSF.Ecto.Types.Inet

  doctest OCSF.Ecto.Types.Inet

  describe "type/0" do
    test "maps to the Postgres :inet column type" do
      assert Inet.type() == :inet
    end
  end

  describe "cast/1" do
    test "accepts an IPv4 tuple and wraps it" do
      assert {:ok, %Postgrex.INET{address: {10, 0, 0, 1}}} = Inet.cast({10, 0, 0, 1})
    end

    test "accepts an IPv6 tuple and wraps it" do
      ipv6 = {0, 0, 0, 0, 0, 0, 0, 1}
      assert {:ok, %Postgrex.INET{address: ^ipv6}} = Inet.cast(ipv6)
    end

    test "passes a %Postgrex.INET{} through unchanged" do
      inet = %Postgrex.INET{address: {10, 0, 0, 1}}
      assert {:ok, ^inet} = Inet.cast(inet)
    end

    test "parses an IPv4 string" do
      assert {:ok, %Postgrex.INET{address: {10, 0, 0, 1}}} = Inet.cast("10.0.0.1")
    end

    test "parses an IPv6 string" do
      assert {:ok, %Postgrex.INET{address: {0, 0, 0, 0, 0, 0, 0, 1}}} = Inet.cast("::1")
    end

    test "rejects malformed strings" do
      assert :error = Inet.cast("not-an-ip")
    end

    test "rejects unsupported input types" do
      assert :error = Inet.cast(12_345)
    end

    test "is nil-safe" do
      assert {:ok, nil} = Inet.cast(nil)
    end
  end

  describe "dump/1" do
    test "wraps an Erlang tuple as %Postgrex.INET{}" do
      assert {:ok, %Postgrex.INET{address: {10, 0, 0, 1}}} = Inet.dump({10, 0, 0, 1})
    end

    test "passes a %Postgrex.INET{} through unchanged" do
      inet = %Postgrex.INET{address: {10, 0, 0, 1}}
      assert {:ok, ^inet} = Inet.dump(inet)
    end

    test "is nil-safe" do
      assert {:ok, nil} = Inet.dump(nil)
    end

    test "rejects unsupported input types" do
      assert :error = Inet.dump("10.0.0.1")
    end
  end

  describe "load/1" do
    test "unwraps a %Postgrex.INET{} into an Erlang tuple" do
      assert {:ok, {10, 0, 0, 1}} = Inet.load(%Postgrex.INET{address: {10, 0, 0, 1}})
    end

    test "is nil-safe" do
      assert {:ok, nil} = Inet.load(nil)
    end

    test "rejects unsupported input types" do
      assert :error = Inet.load({10, 0, 0, 1})
    end
  end

  describe "cast/1 -> dump/1 -> load/1 round-trip" do
    test "preserves an IPv4 tuple" do
      {:ok, cast} = Inet.cast({10, 0, 0, 1})
      {:ok, dumped} = Inet.dump(cast)
      {:ok, loaded} = Inet.load(dumped)
      assert loaded == {10, 0, 0, 1}
    end

    test "preserves an IPv6 tuple" do
      ipv6 = {0, 0, 0, 0, 0, 0, 0, 1}
      {:ok, cast} = Inet.cast(ipv6)
      {:ok, dumped} = Inet.dump(cast)
      {:ok, loaded} = Inet.load(dumped)
      assert loaded == ipv6
    end

    test "preserves nil across the round-trip" do
      {:ok, cast} = Inet.cast(nil)
      {:ok, dumped} = Inet.dump(cast)
      {:ok, loaded} = Inet.load(dumped)
      assert loaded == nil
    end
  end
end
