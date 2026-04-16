defmodule OCSF.Ecto.Types.Inet do
  @moduledoc """
  Ecto type for Postgres `INET` columns.

  Accepts Erlang `:inet.ip_address()` tuples or string representations
  (e.g. `"10.0.0.1"`, `"::1"`). Stores as Postgrex `%Postgrex.INET{}`.
  """

  use Ecto.Type

  @impl true
  def type, do: :inet

  @impl true
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

  @impl true
  def load(%Postgrex.INET{} = inet), do: {:ok, inet.address}
  def load(nil), do: {:ok, nil}
  def load(_), do: :error

  @impl true
  def dump(%Postgrex.INET{} = inet), do: {:ok, inet}
  def dump(ip) when is_tuple(ip), do: {:ok, %Postgrex.INET{address: ip}}
  def dump(nil), do: {:ok, nil}
  def dump(_), do: :error
end
