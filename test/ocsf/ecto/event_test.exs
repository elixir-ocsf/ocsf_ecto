defmodule OCSF.Ecto.EventTest do
  use OCSF.Ecto.DataCase, async: true

  alias OCSF.Ecto.Event, as: EctoEvent

  describe "schema" do
    test "inserts with required fields" do
      uid = OCSF.UUID.v7_string()

      assert {:ok, event} =
               %EctoEvent{}
               |> Ecto.Changeset.cast(required_attrs(uid), Map.keys(required_attrs(uid)))
               |> Repo.insert()

      assert event.id == uid
    end

    test "rejects insert when a required column is missing" do
      # metadata__uid is declared null: false in the migration
      attrs = required_attrs(OCSF.UUID.v7_string()) |> Map.delete(:metadata__uid)

      assert_raise Postgrex.Error, fn ->
        %EctoEvent{}
        |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
        |> Repo.insert()
      end
    end
  end

  describe "Cloak encryption" do
    test "user__name ciphertext does NOT contain the plaintext" do
      uid = OCSF.UUID.v7_string()
      insert_with_user_name!(uid, "Alice Smith")

      assert raw = raw_user_name!(uid)
      assert is_binary(raw) and byte_size(raw) > 0
      refute String.contains?(raw, "Alice Smith")
    end

    test "user__name round-trips as plaintext via Ecto" do
      uid = OCSF.UUID.v7_string()
      insert_with_user_name!(uid, "Alice Smith")

      [row] = Repo.all(EctoEvent)
      assert row.user__name == "Alice Smith"
    end
  end

  # -- helpers --

  defp required_attrs(uid) do
    %{
      id: uid,
      time: DateTime.utc_now(),
      metadata__uid: uid,
      metadata__version: "1.8.0",
      category_uid: 3,
      class_uid: 3002,
      type_uid: 300_201,
      activity_id: 1,
      severity_id: 1,
      status_id: 1
    }
  end

  defp insert_with_user_name!(uid, name) do
    attrs = Map.put(required_attrs(uid), :user__name, name)

    {:ok, _} =
      %EctoEvent{}
      |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
      |> Repo.insert()

    :ok
  end

  defp raw_user_name!(uid) do
    {:ok, uid_bin} = Ecto.UUID.dump(uid)

    {:ok, %{rows: [[raw]]}} =
      Repo.query("SELECT user__name FROM ocsf_event__logs WHERE id = $1", [uid_bin])

    raw
  end
end
