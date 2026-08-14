require "rails_helper"

RSpec.describe PayloadFieldAnalyzer do
  let(:route) { Route.create!(path: "/users/:id", http_method: "POST") }

  def create_error_payload(body)
    event = ErrorEvent.create!(
      route: route,
      datadog_event_id: SecureRandom.uuid,
      occurred_at: Time.current
    )
    Payload.create!(error_event: event, body: body)
  end

  it "records null_value anomalies with the rate among error payloads" do
    create_error_payload({ "email" => nil })
    create_error_payload({ "email" => "a@example.com" })

    described_class.analyze(route)

    stat = route.payload_field_stats.find_by(field_path: "email", anomaly_type: "null_value")
    expect(stat.error_count).to eq(1)
    expect(stat.error_rate).to eq(0.5)
  end

  it "records missing_field anomalies for fields absent in some payloads" do
    create_error_payload({ "email" => "a@example.com", "age" => 30 })
    create_error_payload({ "email" => "b@example.com" })

    described_class.analyze(route)

    stat = route.payload_field_stats.find_by(field_path: "age", anomaly_type: "missing_field")
    expect(stat.error_count).to eq(1)
  end

  it "records type_mismatch anomalies for minority value types" do
    create_error_payload({ "age" => 30 })
    create_error_payload({ "age" => 31 })
    create_error_payload({ "age" => "thirty" })

    described_class.analyze(route)

    stat = route.payload_field_stats.find_by(field_path: "age", anomaly_type: "type_mismatch")
    expect(stat.error_count).to eq(1)
  end

  it "is idempotent across runs (upserts, no duplicates)" do
    create_error_payload({ "email" => nil })

    2.times { described_class.analyze(route) }

    expect(route.payload_field_stats.where(field_path: "email").count).to eq(1)
  end
end
