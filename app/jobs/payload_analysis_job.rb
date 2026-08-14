# Recomputes payload_field_stats for routes that had error activity within
# the shared sync window. Enqueued by DatadogSyncJob after each successful
# sync; safe to run repeatedly (PayloadFieldAnalyzer upserts against the
# unique index on (route_id, field_path, anomaly_type)).
class PayloadAnalysisJob < ApplicationJob
  queue_as :sync_datadog

  def perform
    routes_with_recent_errors.find_each do |route|
      PayloadFieldAnalyzer.analyze(route)
    rescue DatadogDataError => e
      Rails.logger.warn(
        "[PayloadAnalysisJob] Skipping route #{route.id} — bad data: #{e.class} #{e.message}"
      )
    rescue StandardError => e
      Rails.logger.error(
        "[PayloadAnalysisJob] Skipping route #{route.id} — unexpected error: #{e.class} #{e.message}\n" \
        "#{e.backtrace&.first(5)&.join("\n")}"
      )
    end
  end

  private

  def routes_with_recent_errors
    Route.joins(:error_events)
      .where(error_events: { occurred_at: Rails.application.config.x.sync_window_minutes.ago.. })
      .distinct
  end
end
