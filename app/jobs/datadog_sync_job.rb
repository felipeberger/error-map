# Polls the Datadog Logs Search API for recent error events and ingests
# them into routes/error_events/payloads. Scheduled via config/recurring.yml
# to run on Solid Queue every 5 minutes.
#
# The sync window is controlled by the SYNC_WINDOW_MINUTES env var (default 10)
# and shared with PayloadAnalysisJob so both jobs stay in sync.
class DatadogSyncJob < ApplicationJob
  queue_as :sync_datadog

  def perform(from: Rails.application.config.x.sync_window_minutes.ago, to: Time.current)
    client = DatadogClient.new
    cursor = nil

    loop do
      page = client.fetch_error_logs(from: from, to: to, cursor: cursor)
      ingest_batch(page["data"])

      cursor = page.dig("meta", "page", "after")
      break if cursor.blank?
    end

    PayloadAnalysisJob.perform_later
  end

  private

  def ingest_batch(events)
    Array(events).each do |event|
      ingest_event(event)
    rescue DatadogDataError => e
      Rails.logger.warn(
        "[DatadogSyncJob] Skipping event #{event["id"].inspect} — bad data: #{e.class} #{e.message}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "[DatadogSyncJob] Skipping event #{event["id"].inspect} — unexpected error: #{e.class} #{e.message}\n" \
        "#{e.backtrace&.first(5)&.join("\n")}"
      )
    end
  end

  def ingest_event(event)
    raise DatadogDataError::UnparsableEventError, "event id is missing" if event["id"].blank?

    attrs = event["attributes"] || {}
    http  = attrs.dig("attributes", "http") || {}

    raise DatadogDataError::MissingAttributeError, "timestamp is missing (event #{event["id"]})" if attrs["timestamp"].blank?
    raise DatadogDataError::MissingAttributeError, "http.method is missing (event #{event["id"]})" if http["method"].blank?

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
      error_event.route       = route
      error_event.occurred_at = attrs["timestamp"]
      error_event.status_code = http["status_code"]
      error_event.error_class = attrs.dig("attributes", "error", "kind")
      error_event.message     = attrs["message"]
    end
  end

  def attach_payload(error_event, http)
    body = http.dig("request", "body")
    return if body.blank?

    Payload.find_or_create_by!(error_event: error_event) do |payload|
      payload.content_type    = http.dig("request", "headers", "content-type")
      payload.body            = body
      payload.param_fingerprint = ParamFingerprint.compute(body)
    end
  end
end
