# Thin wrapper around the Datadog Logs Search API.
# https://docs.datadoghq.com/api/latest/logs/#search-logs
class DatadogClient
  BASE_URL = "https://api.#{ENV.fetch('DD_SITE', 'datadoghq.com')}".freeze

  def initialize(api_key: ENV.fetch("DD_API_KEY"), app_key: ENV.fetch("DD_APP_KEY"))
    @conn = Faraday.new(url: BASE_URL) do |f|
      f.headers["DD-API-KEY"] = api_key
      f.headers["DD-APPLICATION-KEY"] = app_key
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end
  end

  # Fetches a page of error logs within the given time window.
  # Pass the `cursor` returned in a previous response's meta.page.after
  # to page through results.
  def fetch_error_logs(from:, to:, cursor: nil)
    body = {
      filter: {
        query: "status:error @http.status_code:>=400",
        from: from.iso8601,
        to: to.iso8601
      },
      page: { limit: 100, cursor: cursor }.compact
    }

    @conn.post("/api/v2/logs/events/search", body).body
  end
end
