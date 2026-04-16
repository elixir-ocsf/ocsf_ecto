defmodule OCSF.Ecto.SinkTest do
  use OCSF.Ecto.DataCase, async: true

  alias OCSF.Ecto.Event, as: EctoEvent
  alias OCSF.Ecto.Sink
  alias OCSF.Events.Authentication

  defp build_event(opts \\ []) do
    default_opts = [
      user: %{
        uid: "018f19fe-6d4c-71c2-a84b-5d2d8c7f1e90",
        name: "Jane Doe",
        email_addr: "jane@example.com",
        org: %{uid: "communitiz-app"}
      },
      http_request: %{url: "/oauth/token", http_method: "POST", user_agent: "Mozilla/5.0"},
      src_endpoint: %{ip: {10, 0, 0, 1}},
      service: %{name: "Cryptr Auth"},
      status: :Success,
      severity: :Informational,
      auth_protocol: :"OAUTH 2.0"
    ]

    {:ok, event} = Authentication.logon(Keyword.merge(default_opts, opts))
    event
  end

  describe "write/1" do
    test "inserts a single event" do
      event = build_event()
      assert :ok = Sink.write([event])
      assert Repo.aggregate(EctoEvent, :count) == 1
    end

    test "inserts multiple events in one call" do
      events = for _ <- 1..5, do: build_event()
      assert :ok = Sink.write(events)
      assert Repo.aggregate(EctoEvent, :count) == 5
    end

    test "persists event with correct class and activity" do
      event = build_event()
      :ok = Sink.write([event])

      [row] = Repo.all(EctoEvent)
      assert row.class_uid == 3002
      assert row.activity_id == 1
      assert row.type_uid == 300_201
      assert row.category_uid == 3
    end

    test "persists severity, status, auth_protocol" do
      event = build_event(status: :Failure, severity: :High, auth_protocol: :SAML)
      :ok = Sink.write([event])

      [row] = Repo.all(EctoEvent)
      assert row.status_id == 2
      assert row.severity_id == 4
      assert row.auth_protocol_id == 5
    end

    test "persists metadata fields" do
      event = build_event()
      :ok = Sink.write([event])

      [row] = Repo.all(EctoEvent)
      assert row.metadata__uid == event.metadata.uid
      assert row.metadata__version == "1.8.0"
      assert row.metadata__product__name == "Cryptr Auth" or row.metadata__product__name == nil
    end
  end

  describe "Cloak encryption" do
    test "user__name and user__email_addr are encrypted at rest" do
      event = build_event()
      :ok = Sink.write([event])

      # Query raw row via raw SQL to verify encryption
      {:ok, %{rows: [[name_bytes, email_bytes]]}} =
        Repo.query("SELECT user__name, user__email_addr FROM ocsf_event__logs")

      # Encrypted bytes should not contain the plaintext
      assert is_binary(name_bytes) and byte_size(name_bytes) > 0
      refute String.contains?(name_bytes, "Jane Doe")
      assert is_binary(email_bytes) and byte_size(email_bytes) > 0
      refute String.contains?(email_bytes, "jane@example.com")
    end

    test "Cloak-encrypted fields round-trip correctly via Ecto" do
      event = build_event()
      :ok = Sink.write([event])

      [row] = Repo.all(EctoEvent)
      assert row.user__name == "Jane Doe"
      assert row.user__email_addr == "jane@example.com"
    end
  end

  describe "policy redaction" do
    test "default policy denies :network by default" do
      event = build_event()
      :ok = Sink.write([event])

      [row] = Repo.all(EctoEvent)
      # network class denied -> http_request__url, user_agent, src_endpoint__ip are nilled
      assert row.http_request__url == nil
      assert row.http_request__user_agent == nil
      assert row.src_endpoint__ip == nil
    end

    test "allows :identifier and :tenant fields" do
      event = build_event()
      :ok = Sink.write([event])

      [row] = Repo.all(EctoEvent)
      assert row.user__uid == event.user.uid
      assert row.user__org__uid == "communitiz-app"
    end
  end

  describe "row_for/1" do
    test "produces a map with all expected columns" do
      event = build_event()
      row = Sink.row_for(event)

      assert row.id == event.metadata.uid
      assert row.class_uid == 3002
      assert row.activity_id == 1
      assert row.type_uid == 300_201
      assert row.metadata__uid == event.metadata.uid
    end
  end

  describe "policy/0" do
    test "returns a %OCSF.Policy{} struct" do
      assert %OCSF.Policy{} = Sink.policy()
    end

    test "denies :network by default" do
      assert :network in Sink.policy().deny
    end
  end

  describe "repo/0" do
    # Override-path testing requires Application.put_env, which is
    # global state and would race with other async: true tests that
    # call Sink.repo/0 via write/1 or health/0. Covered by a
    # dedicated async: false case in sink_repo_override_test.exs.
    test "returns OCSF.Ecto.Repo by default" do
      assert Sink.repo() == OCSF.Ecto.Repo
    end
  end

  describe "health/0" do
    test "returns :ok when repo responds" do
      assert Sink.health() == :ok
    end
  end

  describe "idempotency (ON CONFLICT DO NOTHING)" do
    test "replaying the same event leaves a single row" do
      event = build_event()

      assert :ok = Sink.write([event])
      assert :ok = Sink.write([event])

      assert Repo.aggregate(EctoEvent, :count) == 1
    end

    test "different events with distinct metadata.uid both persist" do
      event_a = build_event()
      event_b = build_event()

      refute event_a.metadata.uid == event_b.metadata.uid

      assert :ok = Sink.write([event_a, event_b])
      assert Repo.aggregate(EctoEvent, :count) == 2
    end
  end

  # A bare spawned process doesn't inherit the sandbox caller chain
  # (Task.async would), so any Repo call raises
  # DBConnection.OwnershipError. That's the closest we can get to a
  # "Repo unavailable" signal without mocking.
  describe "error paths" do
    test "write/1 returns {:error, _} when the Repo raises" do
      event = build_event()
      parent = self()

      spawn(fn -> send(parent, {:result, Sink.write([event])}) end)

      assert_receive {:result, {:error, %DBConnection.OwnershipError{}}}, 1_000
    end

    test "health/0 returns {:down, reason} when the Repo raises" do
      parent = self()

      spawn(fn -> send(parent, {:result, Sink.health()}) end)

      assert_receive {:result, {:down, %DBConnection.OwnershipError{}}}, 1_000
    end
  end
end
