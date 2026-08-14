# Recomputes payload_field_stats for routes that had error activity within
# the shared SYNC_WINDOW_MINUTES window. Enqueued by DatadogSyncJob after
# each successful sync; safe to run repeatedly (PayloadFieldAnalyzer upserts
# against the unique index on (route_id, field_path, anomaly_type)).
#
# The analysis window matches DatadogSyncJob's sync window via the shared
# SYNC_WINDOW_MINUTES constant so we only re-analyze routes touched by the
# most recent sync, not the full 24h of history on every run.
class PayloadAnalysisJob < ApplicationJob
  queue_as :sync_datadog

  class RouteAnalysisError < StandardError; end

  def perform
    routes_with_recent_errors.find_each do |route|
      PayloadFieldAnalyzer.analyze(route)
    rescue RouteAnalysisError => e
      Rails.logger.error("[PayloadAnalysisJob] Route #{route.id}: #{e.cause.class} #{e.message}")
    end
  end

  private

  def routes_with_recent_errors
    Route.joins(:error_events)
      .where(error_events: { occurred_at: SYNC_WINDOW_MINUTES.ago.. })
      .distinct
  end
end
