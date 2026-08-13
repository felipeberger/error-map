# Normalizes raw request paths captured from Datadog logs into a stable
# route identity by stripping dynamic segments (numeric IDs, UUIDs) so that
# e.g. "/users/123" and "/users/456" both resolve to the same Route record.
class RouteNormalizer
  UUID_SEGMENT = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
  NUMERIC_ID_SEGMENT = /\A\d+\z/

  def self.find_or_create(raw_path:, http_method:, service: nil, environment: nil)
    new(raw_path).find_or_create(http_method: http_method, service: service, environment: environment)
  end

  def initialize(raw_path)
    @raw_path = raw_path.to_s
  end

  def find_or_create(http_method:, service: nil, environment: nil)
    Route.find_or_create_by!(
      path: normalized_path,
      http_method: http_method.to_s.upcase,
      service: service,
      environment: environment
    )
  end

  def normalized_path
    segments = path_without_query.split("/").map do |segment|
      dynamic_segment?(segment) ? ":id" : segment
    end

    segments.join("/").presence || "/"
  end

  private

  def path_without_query
    @raw_path.split("?").first.to_s
  end

  def dynamic_segment?(segment)
    segment.match?(UUID_SEGMENT) || segment.match?(NUMERIC_ID_SEGMENT)
  end
end
