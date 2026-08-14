# Shared sync window used by DatadogSyncJob and PayloadAnalysisJob.
# Set SYNC_WINDOW_MINUTES in your environment to override (default: 10).
# Both jobs read from Rails.application.config.x.sync_window_minutes so
# the analysis window always matches the ingestion window.
Rails.application.config.x.sync_window_minutes = ENV.fetch("SYNC_WINDOW_MINUTES", 10).to_i.minutes
