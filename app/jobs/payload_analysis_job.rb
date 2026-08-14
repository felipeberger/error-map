# Recomputes payload_field_stats for routes with recent error activity.
# Enqueued by DatadogSyncJob after each successful sync; safe to run
# repeatedly (PayloadFieldAnalyzer upserts against the unique index on
# (route_id, field_path, anomaly_type)).
class PayloadAnalysisJob < ApplicationJob
  queue_as :sync_datadog

  RECENT_WINDOW = 24.hours

  def perform
    routes_with_recent_errors.find_each do |route|
      PayloadFieldAnalyzer.analyze(route)
    rescue StandardError => e
      Rails.logger.error("[PayloadAnalysisJob] Route #{route.id}: #{e.class} #{e.message}")
    end
  end

  private

  def routes_with_recent_errors
    Route.joins(:error_events)
      .where(error_events: { occurred_at: RECENT_WINDOW.ago.. })
      .distinct
  end
end
