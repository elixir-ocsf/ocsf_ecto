defmodule OCSF.Ecto.EventJsonConformanceTest do
  # Sophisticated, dashboard-grade events across the OCSF classes the
  # dashboard surfaces (SSO sign-in, user / group / role / entity management,
  # API activity, session authorization). Every example is built through the
  # real builder — which runs `OCSF.validate/1` — so it is a valid OCSF 1.9
  # event by construction; the tests re-assert conformance of the encoder's
  # output via `OCSF.Deserializer.from_map/1` (the library's conformance gate,
  # tracking `OCSF.version/0`).
  #
  # async: false — installs an allow-all sink policy so redaction never strips
  # a required field (e.g. API Activity requires `src_endpoint`, class
  # `:network`), letting every class round-trip fully and conformantly.
  use OCSF.Ecto.DataCase, async: false

  alias OCSF.Ecto.Event, as: EctoEvent
  alias OCSF.Ecto.Sink

  alias OCSF.Events.{
    ApiActivity,
    Authentication,
    AuthorizeSession,
    EntityManagement,
    GroupManagement,
    RoleManagement,
    UserManagement
  }

  @allow_all %OCSF.Policy{
    allow: [:identifier, :tenant, :taxonomic, :temporal, :contact, :identity, :network],
    deny: [],
    transform: []
  }

  setup do
    prev = Application.get_env(:ocsf_ecto, Sink)
    Application.put_env(:ocsf_ecto, Sink, policy: @allow_all)

    on_exit(fn ->
      if prev,
        do: Application.put_env(:ocsf_ecto, Sink, prev),
        else: Application.delete_env(:ocsf_ecto, Sink)
    end)

    :ok
  end

  # --- dashboard-grade example events ---------------------------------------

  defp sso_signin do
    {:ok, event} =
      Authentication.logon(
        user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Alice",
          email_addr: "alice@acme.co",
          org: %{uid: "org-1"}
        },
        http_request: %{
          url: "https://acme.co/sso/saml/acs",
          user_agent: "Mozilla/5.0",
          http_method: "POST"
        },
        src_endpoint: %{ip: {203, 0, 113, 7}},
        service: %{name: "Cryptr SSO"},
        auth_protocol: :SAML,
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp user_update do
    {:ok, event} =
      UserManagement.update(
        user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Alice",
          email_addr: "alice@acme.co",
          org: %{uid: "org-1"}
        },
        updated_user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Alice Cooper",
          email_addr: "alice.c@acme.co"
        },
        actor: %{user: %{uid: "admin-1", name: "Bob", email_addr: "bob@acme.co"}},
        http_request: %{
          url: "https://acme.co/users/u-1",
          user_agent: "Mozilla/5.0",
          http_method: "PATCH"
        },
        service: %{name: "iam"},
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}, profiles: ["cloud"]}
      )

    event
  end

  defp group_add_user do
    {:ok, event} =
      GroupManagement.add_user(
        group: %{uid: "g-1", name: "Engineering", type: "team"},
        user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Alice",
          email_addr: "alice@acme.co"
        },
        actor: %{user: %{uid: "admin-1", name: "Bob", email_addr: "bob@acme.co"}},
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp role_assign do
    {:ok, event} =
      RoleManagement.assign_privileges(
        iam_role: %{name: "admin", uid: "role-1"},
        updated_role: %{name: "auditor", uid: "role-9"},
        privileges: ["policy:write", "policy:read"],
        resources: [%{uid: "arn:res:1", type: "bucket"}, %{uid: "arn:res:2", type: "bucket"}],
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp entity_create do
    {:ok, event} =
      EntityManagement.create(
        entity: %{uid: "e-1", type: "User", name: "Jane Roe", email: "jane@acme.co"},
        actor: %{user: %{uid: "admin-1", name: "Bob", email_addr: "bob@acme.co"}},
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp api_create do
    {:ok, event} =
      ApiActivity.create(
        api: %{operation: "CreateUser", version: "v1", service: %{name: "scim"}},
        actor: %{user: %{uid: "admin-1", name: "Bob", email_addr: "bob@acme.co"}},
        src_endpoint: %{ip: {203, 0, 113, 9}},
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp session_assign_groups do
    {:ok, event} =
      AuthorizeSession.assign_groups(
        user: %{
          uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
          name: "Alice",
          email_addr: "alice@acme.co",
          org: %{uid: "org-1"}
        },
        groups: [%{uid: "g-1", name: "Engineering"}, %{uid: "g-2", name: "Admins"}],
        severity: :Informational,
        status: :Success,
        metadata: %{product: %{name: "cryptr"}}
      )

    event
  end

  defp dashboard_events do
    [
      {"SSO sign-in (Authentication 3002, SAML)", sso_signin()},
      {"User update (User Management 3007)", user_update()},
      {"Group add-user (Group Management 3006)", group_add_user()},
      {"Role assign-privileges (Role Management 3008)", role_assign()},
      {"Entity create (Entity Management 3004)", entity_create()},
      {"API activity create (6003)", api_create()},
      {"Session assign-groups (Authorize Session 3003)", session_assign_groups()}
    ]
  end

  # --- helpers ---------------------------------------------------------------

  defp json(term), do: term |> Jason.encode!() |> Jason.decode!()

  defp store_and_load(event) do
    :ok = Sink.write([event])
    Repo.get(EctoEvent, event.metadata.uid)
  end

  defp raw_column(uid, column) do
    %{rows: [[bytes]]} =
      Repo.query!("SELECT #{column} FROM ocsf_event__logs WHERE id = $1", [Ecto.UUID.dump!(uid)])

    bytes
  end

  # --- tests -----------------------------------------------------------------

  describe "dashboard-grade events" do
    test "each example is OCSF-conformant and reconstructs losslessly" do
      for {label, event} <- dashboard_events() do
        # The source example is a valid OCSF 1.9 event (the builder ran
        # OCSF.validate — the library's conformance gate).
        assert match?({:ok, _}, OCSF.Deserializer.from_map(OCSF.to_map(event))),
               "source not OCSF-conformant: #{label}"

        encoded = event |> store_and_load() |> json()

        # The stored row re-encodes to a conformant OCSF event...
        assert match?({:ok, _}, OCSF.Deserializer.from_map(encoded)),
               "encoded row not OCSF-conformant: #{label}"

        # ...and losslessly versus the stored (redacted) view.
        expected = json(OCSF.to_map(OCSF.Policy.apply(Sink.policy(), event)))
        assert expected == encoded, "not lossless: #{label}"
      end
    end
  end

  describe "every encrypted PII column is ciphertext at rest" do
    test "actor, updated_user and entity never land as cleartext" do
      # user_update carries actor + updated_user; entity_create carries entity.
      user = user_update()
      :ok = Sink.write([user])
      entity = entity_create()
      :ok = Sink.write([entity])

      actor_bytes = raw_column(user.metadata.uid, "actor")
      updated_user_bytes = raw_column(user.metadata.uid, "updated_user")
      entity_bytes = raw_column(entity.metadata.uid, "entity")

      for bytes <- [actor_bytes, updated_user_bytes, entity_bytes] do
        assert is_binary(bytes)
      end

      # None of the PII appears in cleartext in the raw column bytes.
      refute actor_bytes =~ "bob@acme.co"
      refute updated_user_bytes =~ "alice.c@acme.co"
      refute entity_bytes =~ "jane@acme.co"
      refute entity_bytes =~ "Jane Roe"

      # ...yet all three decrypt and round-trip through the encoder.
      encoded_user = Repo.get(EctoEvent, user.metadata.uid) |> json()
      assert encoded_user["actor"]["user"]["email_addr"] == "bob@acme.co"
      assert encoded_user["updated_user"]["email_addr"] == "alice.c@acme.co"

      encoded_entity = Repo.get(EctoEvent, entity.metadata.uid) |> json()
      assert encoded_entity["entity"]["email"] == "jane@acme.co"
    end
  end
end
