require "rails_helper"

RSpec.describe DatadogSyncJob, type: :job do
  let(:client) { instance_double(DatadogClient) }
  let(:from_time) { 10.minutes.ago }
  let(:to_time) { Time.current }

  before do
    allow(DatadogClient).to receive(:new).and_return(client)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe "#perform" do
    context "with valid single-page response" do
      let(:valid_event) do
        {
          "id" => "evt-123",
          "attributes" => {
            "timestamp" => 5.minutes.ago.iso8601,
            "service" => "api",
            "message" => "Something went wrong",
            "attributes" => {
              "env" => "production",
              "http" => {
                "method" => "POST",
                "status_code" => 500,
                "url_details" => { "path" => "/users/123" },
                "request" => {
                  "body" => { "email" => "user@example.com" },
                  "headers" => { "content-type" => "application/json" }
                }
              },
              "error" => { "kind" => "ActiveRecord::RecordNotFound" }
            }
          }
        }
      end

      let(:response) do
        {
          "data" => [valid_event],
          "meta" => { "page" => { "after" => nil } }
        }
      end

      before do
        allow(client).to receive(:fetch_error_logs)
          .with(from: from_time, to: to_time, cursor: nil)
          .and_return(response)
      end

      it "creates a route via RouteNormalizer" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.to change(Route, :count).by(1)

        route = Route.last
        expect(route.path).to eq("/users/:id")
        expect(route.http_method).to eq("POST")
        expect(route.service).to eq("api")
        expect(route.environment).to eq("production")
      end

      it "creates an ErrorEvent with correct attributes" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.to change(ErrorEvent, :count).by(1)

        event = ErrorEvent.last
        expect(event.datadog_event_id).to eq("evt-123")
        expect(event.status_code).to eq(500)
        expect(event.error_class).to eq("ActiveRecord::RecordNotFound")
        expect(event.message).to eq("Something went wrong")
      end

      it "creates a Payload with fingerprint" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.to change(Payload, :count).by(1)

        payload = Payload.last
        expect(payload.body).to eq({ "email" => "user@example.com" })
        expect(payload.content_type).to eq("application/json")
        expect(payload.param_fingerprint).not_to be_nil
      end

      it "enqueues PayloadAnalysisJob after sync" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.to have_enqueued_job(PayloadAnalysisJob)
      end
    end

    context "with paginated response" do
      let(:page1) do
        {
          "data" => [
            {
              "id" => "evt-1",
              "attributes" => {
                "timestamp" => 5.minutes.ago.iso8601,
                "attributes" => {
                  "http" => { "method" => "GET", "url_details" => { "path" => "/health" } }
                }
              }
            }
          ],
          "meta" => { "page" => { "after" => "cursor-abc" } }
        }
      end

      let(:page2) do
        {
          "data" => [
            {
              "id" => "evt-2",
              "attributes" => {
                "timestamp" => 4.minutes.ago.iso8601,
                "attributes" => {
                  "http" => { "method" => "POST", "url_details" => { "path" => "/users" } }
                }
              }
            }
          ],
          "meta" => { "page" => { "after" => nil } }
        }
      end

      before do
        allow(client).to receive(:fetch_error_logs)
          .with(from: from_time, to: to_time, cursor: nil)
          .and_return(page1)
        allow(client).to receive(:fetch_error_logs)
          .with(from: from_time, to: to_time, cursor: "cursor-abc")
          .and_return(page2)
      end

      it "follows pagination cursors and ingests all events" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.to change(ErrorEvent, :count).by(2)

        expect(ErrorEvent.pluck(:datadog_event_id)).to contain_exactly("evt-1", "evt-2")
      end
    end

    context "with events missing required fields" do
      it "raises DatadogDataError::UnparsableEventError for missing event id" do
        response = {
          "data" => [{ "id" => nil, "attributes" => {} }],
          "meta" => { "page" => { "after" => nil } }
        }
        allow(client).to receive(:fetch_error_logs).and_return(response)

        described_class.perform_now(from: from_time, to: to_time)

        expect(Rails.logger).to have_received(:warn).with(
          /Skipping event nil — bad data: DatadogDataError::UnparsableEventError/
        )
      end

      it "raises DatadogDataError::MissingAttributeError for missing timestamp" do
        response = {
          "data" => [
            {
              "id" => "evt-no-timestamp",
              "attributes" => {
                "timestamp" => nil,
                "attributes" => {
                  "http" => { "method" => "GET" }
                }
              }
            }
          ],
          "meta" => { "page" => { "after" => nil } }
        }
        allow(client).to receive(:fetch_error_logs).and_return(response)

        described_class.perform_now(from: from_time, to: to_time)

        expect(Rails.logger).to have_received(:warn).with(
          /Skipping event "evt-no-timestamp" — bad data: DatadogDataError::MissingAttributeError/
        )
      end

      it "raises DatadogDataError::MissingAttributeError for missing http.method" do
        response = {
          "data" => [
            {
              "id" => "evt-no-method",
              "attributes" => {
                "timestamp" => 5.minutes.ago.iso8601,
                "attributes" => {
                  "http" => { "method" => nil }
                }
              }
            }
          ],
          "meta" => { "page" => { "after" => nil } }
        }
        allow(client).to receive(:fetch_error_logs).and_return(response)

        described_class.perform_now(from: from_time, to: to_time)

        expect(Rails.logger).to have_received(:warn).with(
          /Skipping event "evt-no-method" — bad data: DatadogDataError::MissingAttributeError/
        )
      end
    end

    context "with events without request body" do
      let(:event_without_body) do
        {
          "id" => "evt-no-body",
          "attributes" => {
            "timestamp" => 5.minutes.ago.iso8601,
            "attributes" => {
              "http" => {
                "method" => "GET",
                "url_details" => { "path" => "/status" },
                "request" => {}
              }
            }
          }
        }
      end

      let(:response) do
        {
          "data" => [event_without_body],
          "meta" => { "page" => { "after" => nil } }
        }
      end

      before do
        allow(client).to receive(:fetch_error_logs).and_return(response)
      end

      it "creates ErrorEvent but skips Payload creation" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.to change(ErrorEvent, :count).by(1)
          .and change(Payload, :count).by(0)
      end
    end

    context "when unexpected errors occur" do
      let(:valid_event) do
        {
          "id" => "evt-crash",
          "attributes" => {
            "timestamp" => 5.minutes.ago.iso8601,
            "attributes" => {
              "http" => { "method" => "POST", "url_details" => { "path" => "/crash" } }
            }
          }
        }
      end

      let(:response) do
        {
          "data" => [valid_event],
          "meta" => { "page" => { "after" => nil } }
        }
      end

      before do
        allow(client).to receive(:fetch_error_logs).and_return(response)
        allow(RouteNormalizer).to receive(:find_or_create).and_raise(StandardError, "DB connection lost")
      end

      it "logs error with backtrace and continues processing" do
        described_class.perform_now(from: from_time, to: to_time)

        expect(Rails.logger).to have_received(:error).with(
          /Skipping event "evt-crash" — unexpected error: StandardError DB connection lost/
        )
      end

      it "does not create any records for the failed event" do
        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.not_to change(ErrorEvent, :count)
      end
    end

    context "with idempotent behavior" do
      let(:duplicate_event) do
        {
          "id" => "evt-duplicate",
          "attributes" => {
            "timestamp" => 5.minutes.ago.iso8601,
            "attributes" => {
              "http" => {
                "method" => "POST",
                "url_details" => { "path" => "/users" }
              }
            }
          }
        }
      end

      let(:response) do
        {
          "data" => [duplicate_event],
          "meta" => { "page" => { "after" => nil } }
        }
      end

      before do
        allow(client).to receive(:fetch_error_logs).and_return(response)
      end

      it "does not create duplicate ErrorEvents on repeated sync" do
        described_class.perform_now(from: from_time, to: to_time)

        expect {
          described_class.perform_now(from: from_time, to: to_time)
        }.not_to change(ErrorEvent, :count)
      end
    end
  end
end
