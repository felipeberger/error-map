# Error-only structural analysis (v1): compares a route's error payloads
# against each other to surface field-level anomalies, upserting results
# into payload_field_stats.
#
# In this version, error_rate = fraction of the route's analyzed error
# payloads exhibiting the anomaly. A baseline of successful-request
# payloads (true error-vs-success comparison) is deferred to a later
# version and will redefine error_rate.
class PayloadFieldAnalyzer
  MISSING_FIELD = "missing_field"
  NULL_VALUE    = "null_value"
  TYPE_MISMATCH = "type_mismatch"

  MAX_PAYLOADS = 500

  def self.analyze(route)
    new(route).analyze
  end

  def initialize(route)
    @route = route
  end

  def analyze
    structures = payload_structures
    return if structures.empty?

    rows = anomaly_rows(structures)
    return if rows.empty?

    PayloadFieldStat.upsert_all(rows, unique_by: %i[route_id field_path anomaly_type])
  end

  private

  # One { "field.path" => "type" } hash per recent error payload.
  def payload_structures
    @route.error_events
      .joins(:payload)
      .order(occurred_at: :desc)
      .limit(MAX_PAYLOADS)
      .includes(:payload)
      .map { |event| flatten(event.payload.body) }
  end

  def flatten(node, prefix = nil, out = {})
    case node
    when Hash
      node.each { |key, value| flatten(value, prefix ? "#{prefix}.#{key}" : key.to_s, out) }
    when Array
      node.each { |value| flatten(value, "#{prefix}[]", out) }
    else
      out[prefix] = json_type(node) if prefix
    end
    out
  end

  def json_type(value)
    case value
    when nil then "null"
    when true, false then "boolean"
    when Integer then "integer"
    when Float then "number"
    when String then "string"
    else value.class.name.downcase
    end
  end

  def anomaly_rows(structures)
    total = structures.size.to_f
    now = Time.current

    structures.flat_map(&:keys).uniq.flat_map do |field_path|
      types = structures.filter_map { |structure| structure[field_path] }

      {
        MISSING_FIELD => structures.count { |structure| !structure.key?(field_path) },
        NULL_VALUE    => types.count("null"),
        TYPE_MISMATCH => type_mismatch_count(types)
      }.filter_map do |anomaly_type, count|
        next if count.zero?

        {
          route_id: @route.id,
          field_path: field_path,
          anomaly_type: anomaly_type,
          error_count: count,
          error_rate: (count / total).round(4),
          last_seen_at: now,
          created_at: now,
          updated_at: now
        }
      end
    end
  end

  # Payloads whose value type differs from the dominant non-null type.
  def type_mismatch_count(types)
    concrete = types.reject { |type| type == "null" }
    return 0 if concrete.uniq.size <= 1

    dominant = concrete.tally.max_by { |_, count| count }.first
    concrete.count { |type| type != dominant }
  end
end
