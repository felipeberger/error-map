# Shared sync window used by DatadogSyncJob and PayloadAnalysisJob.
# Set SYNC_WINDOW_MINUTES in your environment to override (default: 10).
# Both jobs read this constant so the analysis window always matches the
# ingestion window — no redundant re-analysis of stale routes.
SYNC_WINDOW_MINUTES = ENV.fetch("SYNC_WINDOW_MINUTES", 10).to_i.minutes
