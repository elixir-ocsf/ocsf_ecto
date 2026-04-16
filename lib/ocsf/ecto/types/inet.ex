defmodule OCSF.Ecto.Types.Inet do
  @moduledoc """
  Ecto type for Postgres `inet` columns.

  Maps the Postgres `inet` type to Erlang `:inet.ip_address/0`
  tuples in Elixir land, round-tripping through
  `Postgrex.INET` on the wire. Nil-safe — `nil` in, `nil` out —
  so `:network`-denied fields round-trip cleanly after policy
  redaction.

  Used by `OCSF.Ecto.Event` on `src_endpoint__ip` and
  `dst_endpoint__ip`. Corresponds to the OCSF
  [`ip_t`](https://schema.ocsf.io/1.8.0/data_types/ip_t) data type.

  ## Accepted cast inputs

  - `:inet.ip_address/0` tuple (IPv4 or IPv6)
  - `String.t()` — parsed via `:inet.parse_address/1`
  - `%Postgrex.INET{}` — passed through
  - `nil`
  """

  use Ecto.Type

  @typedoc "An Erlang IP address tuple — 4 octets for IPv4, 8 for IPv6."
  @type ip :: :inet.ip_address()

  @doc """
  Returns the underlying Ecto type name.

  ## Examples

      iex> OCSF.Ecto.Types.Inet.type()
      :inet
  """
  @impl true
  @spec type() :: :inet
  def type, do: :inet

  @doc """
  Casts user-facing input to the internal representation.

  Accepts Erlang IP tuples, string IPs (IPv4 / IPv6), existing
  `%Postgrex.INET{}` values, or `nil`. Returns `:error` for any
  other input.

  ## Examples

      iex> OCSF.Ecto.Types.Inet.cast({10, 0, 0, 1})
      {:ok, %Postgrex.INET{address: {10, 0, 0, 1}, netmask: nil}}

      iex> OCSF.Ecto.Types.Inet.cast("::1")
      {:ok, %Postgrex.INET{address: {0, 0, 0, 0, 0, 0, 0, 1}, netmask: nil}}

      iex> OCSF.Ecto.Types.Inet.cast(nil)
      {:ok, nil}

      iex> OCSF.Ecto.Types.Inet.cast("not-an-ip")
      :error
  """
  @impl true
  @spec cast(term) :: {:ok, Postgrex.INET.t() | nil} | :error
  def cast(%Postgrex.INET{} = inet), do: {:ok, inet}

  def cast(nil), do: {:ok, nil}

  def cast(ip) when is_tuple(ip) do
    {:ok, %Postgrex.INET{address: ip}}
  end

  def cast(str) when is_binary(str) do
    case :inet.parse_address(String.to_charlist(str)) do
      {:ok, addr} -> {:ok, %Postgrex.INET{address: addr}}
      {:error, _} -> :error
    end
  end

  def cast(_), do: :error

  @doc """
  Decodes a value coming out of the database.

  Unwraps `%Postgrex.INET{}` into a plain Erlang IP tuple so
  application code never has to know about the Postgrex wrapper.

  ## Examples

      iex> OCSF.Ecto.Types.Inet.load(%Postgrex.INET{address: {10, 0, 0, 1}})
      {:ok, {10, 0, 0, 1}}

      iex> OCSF.Ecto.Types.Inet.load(nil)
      {:ok, nil}
  """
  @impl true
  @spec load(term) :: {:ok, ip() | nil} | :error
  def load(%Postgrex.INET{} = inet), do: {:ok, inet.address}
  def load(nil), do: {:ok, nil}
  def load(_), do: :error

  @doc """
  Encodes a value on its way to the database.

  Accepts either a plain Erlang IP tuple or an existing
  `%Postgrex.INET{}`. Strings are rejected — callers should
  `cast/1` them first.

  ## Examples

      iex> OCSF.Ecto.Types.Inet.dump({10, 0, 0, 1})
      {:ok, %Postgrex.INET{address: {10, 0, 0, 1}, netmask: nil}}

      iex> OCSF.Ecto.Types.Inet.dump(nil)
      {:ok, nil}
  """
  @impl true
  @spec dump(term) :: {:ok, Postgrex.INET.t() | nil} | :error
  def dump(%Postgrex.INET{} = inet), do: {:ok, inet}
  def dump(ip) when is_tuple(ip), do: {:ok, %Postgrex.INET{address: ip}}
  def dump(nil), do: {:ok, nil}
  def dump(_), do: :error
end
