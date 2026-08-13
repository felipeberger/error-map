# Polls the Datadog Logs Search API for recent error events and ingests
# them into routes/error_events/payloads. Scheduled via config/recurring.yml
# to run on Solid Queue every 5 minutes.
class DatadogSyncJob < ApplicationJob
  queue_as :sync_datadog

  def perform(from: 10.minutes.ago, to: Time.current)
    client = DatadogClient.new
    cursor = nil

    loop do
      page = client.fetch_error_logs(from: from, to: to, cursor: cursor)
      ingest_batch(page["data"])

      cursor = page.dig("meta", "page", "after")
      break if cursor.blank?
    end
  end

  private

  def ingest_batch(events)
    Array(events).each { |event| ingest_event(event) }
  end

  def ingest_event(event)
    attrs = event["attributes"] || {}
    http = attrs.dig("attributes", "http") || {}

    route = RouteNormalizer.find_or_create(
      raw_path: http.dig("url_details", "path") || http["url"],
      http_method: http["method"],
      service: attrs["service"],
      environment: attrs.dig("attributes", "env")
    )

    error_event = find_or_create_error_event(event, attrs, http, route)
    attach_payload(error_event, http)
  end

  def find_or_create_error_event(event, attrs, http, route)
    ErrorEvent.find_or_create_by!(datadog_event_id: event["id"]) do |error_event|
      error_event.route = route
      error_event.occurred_at = attrs["timestamp"]
      error_event.status_code = http["status_code"]
      error_event.error_class = attrs.dig("attributes", "error", "kind")
      error_event.message = attrs["message"]
    end
  end

  def attach_payload(error_event, http)
    body = http.dig("request", "body")
    return if body.blank?

    Payload.find_or_create_by!(error_event: error_event) do |payload|
      payload.content_type = http.dig("request", "headers", "content-type")
      payload.body = body
    end
  end
end
