defmodule OCSF.Ecto.EventJsonTest do
  use OCSF.Ecto.DataCase, async: true

  alias OCSF.Ecto.Event, as: EctoEvent
  alias OCSF.Ecto.Sink
  alias OCSF.Events.{RoleManagement, UserManagement}

  # User Management (3007) Assign Roles — top-level `user`, the `iam_roles`
  # list, `privileges`, `metadata.profiles`, and a PII `actor` (encrypted).
  defp user_event do
    {:ok, event} =
      UserManagement.assign_roles(
        user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Alice",
          email_addr: "alice@acme.co",
          org: %{uid: "org-1"}
        },
        actor: %{user: %{uid: "actor-1", name: "Bob", email_addr: "bob@acme.co"}},
        iam_roles: [%{name: "admin", uid: "role-1"}, %{name: "auditor", uid: "role-9"}],
        privileges: ["policy:write", "policy:read"],
        http_request: %{
          url: "https://acme.co/users",
          user_agent: "Mozilla/5.0",
          http_method: "POST"
        },
        service: %{name: "iam"},
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}, profiles: ["cloud"]}
      )

    event
  end

  # Role Management (3008) Assign Privileges — a single `iam_role`,
  # `updated_role`, `privileges` and `resources` lists.
  defp role_event do
    {:ok, event} =
      RoleManagement.assign_privileges(
        iam_role: %{name: "admin", uid: "role-1"},
        updated_role: %{name: "auditor", uid: "role-9"},
        privileges: ["policy:write"],
        resources: [%{uid: "arn:res:1", type: "bucket"}, %{uid: "arn:res:2", type: "bucket"}],
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp json(term), do: term |> Jason.encode!() |> Jason.decode!()

  defp store_and_load(event) do
    :ok = Sink.write([event])
    Repo.get(EctoEvent, event.metadata.uid)
  end

  describe "Jason.encode!/1 of a stored row (round-trip)" do
    test "reconstructs the event losslessly across classes" do
      for event <- [user_event(), role_event()] do
        row = store_and_load(event)
        refute is_nil(row)

        # The redacted event is what the sink stored; encoding the row must
        # equal its canonical OCSF JSON — proving lossless reconstruction
        # and (since OCSF.to_map is schema-conformant) conformance too.
        expected = OCSF.to_map(OCSF.Policy.apply(Sink.policy(), event))

        assert json(row) == json(expected)
      end
    end

    test "carries the completeness fields and re-derived labels" do
      encoded = user_event() |> store_and_load() |> json()

      # Re-derived labels (not stored — resolved via OCSF.to_map).
      assert encoded["class_name"] == "User Management"
      assert encoded["status"] == "Success"

      # jsonb completeness fields, reconstructed at their nested path.
      assert encoded["privileges"] == ["policy:write", "policy:read"]
      assert [%{"name" => "admin"}, %{"name" => "auditor"}] = encoded["iam_roles"]
      assert encoded["metadata"]["profiles"] == ["cloud"]

      # Flattened scalar columns, un-flattened back to nested OCSF.
      assert encoded["user"]["email_addr"] == "alice@acme.co"
      assert encoded["user"]["org"]["uid"] == "org-1"

      # PII sub-object, decrypted and reconstructed.
      assert encoded["actor"]["user"]["email_addr"] == "bob@acme.co"
    end

    test "reconstructs role-class jsonb fields (single object + lists)" do
      encoded = role_event() |> store_and_load() |> json()

      assert encoded["iam_role"]["name"] == "admin"
      assert encoded["updated_role"]["name"] == "auditor"
      assert encoded["privileges"] == ["policy:write"]

      assert [%{"uid" => "arn:res:1", "type" => "bucket"}, %{"uid" => "arn:res:2"}] =
               encoded["resources"]
    end
  end

  describe "PII columns at rest" do
    test "the actor sub-object is stored as ciphertext, not cleartext" do
      event = user_event()
      :ok = Sink.write([event])

      # Raw column bytes straight from Postgres, bypassing the EncryptedMap
      # type — the PII must not be sitting there in cleartext.
      %{rows: [[actor_bytes]]} =
        Repo.query!("SELECT actor FROM ocsf_event__logs WHERE id = $1", [
          Ecto.UUID.dump!(event.metadata.uid)
        ])

      assert is_binary(actor_bytes)
      refute actor_bytes =~ "bob@acme.co"
      refute actor_bytes =~ "actor-1"

      # ...but it decrypts and round-trips through the encoder.
      encoded = Repo.get(EctoEvent, event.metadata.uid) |> json()
      assert encoded["actor"]["user"]["email_addr"] == "bob@acme.co"
    end
  end

  describe "to_ocsf_map/1 (in-memory)" do
    test "formats Inet columns to their string form" do
      row = %EctoEvent{
        metadata__uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
        metadata__version: OCSF.version(),
        category_uid: 3,
        class_uid: 3007,
        type_uid: 300_716,
        activity_id: 16,
        severity_id: 1,
        status_id: 1,
        user__uid: "u-1",
        src_endpoint__ip: {10, 0, 0, 1}
      }

      # Path-independent: the tuple is rendered as a dotted-quad string in
      # the JSON, never leaked as an Erlang tuple.
      assert Jason.encode!(row) =~ "10.0.0.1"
    end
  end
end
