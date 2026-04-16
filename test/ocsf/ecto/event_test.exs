defmodule OCSF.Ecto.EventTest do
  use OCSF.Ecto.DataCase, async: true

  alias OCSF.Ecto.Event, as: EctoEvent

  describe "schema" do
    test "can be inserted with required fields" do
      uid = OCSF.UUID.v7_string()

      attrs = %{
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

      assert {:ok, event} =
               %EctoEvent{}
               |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
               |> Repo.insert()

      assert event.id == uid
    end

    test "encrypts user__name via Cloak" do
      uid = OCSF.UUID.v7_string()

      attrs = %{
        id: uid,
        time: DateTime.utc_now(),
        metadata__uid: uid,
        metadata__version: "1.8.0",
        category_uid: 3,
        class_uid: 3002,
        type_uid: 300_201,
        activity_id: 1,
        severity_id: 1,
        status_id: 1,
        user__name: "Alice Smith"
      }

      {:ok, _} =
        %EctoEvent{}
        |> Ecto.Changeset.cast(attrs, Map.keys(attrs))
        |> Repo.insert()

      # Raw bytes are encrypted
      {:ok, uid_bin} = Ecto.UUID.dump(uid)

      {:ok, %{rows: [[raw]]}} =
        Repo.query("SELECT user__name FROM ocsf_event__logs WHERE id = $1", [uid_bin])

      refute String.contains?(raw, "Alice Smith")

      # Ecto decrypts on read
      [row] = Repo.all(EctoEvent)
      assert row.user__name == "Alice Smith"
    end
  end
end
