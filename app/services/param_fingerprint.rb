# Computes a stable structural fingerprint for a request payload.
# Two payloads with the same field paths and value types (regardless of
# actual values) share a fingerprint, letting us group payload "shapes"
# per route via payloads.param_fingerprint.
class ParamFingerprint
  def self.compute(body)
    new(body).compute
  end

  def initialize(body)
    @body = body
  end

  def compute
    Digest::SHA256.hexdigest(structure(@body).sort.join("\n"))
  end

  private

  # Flattens the payload into "field.path:type" entries, e.g.
  #   { "user" => { "id" => 1, "tags" => [ "a" ] } }
  #   => ["user.id:integer", "user.tags[]:string"]
  def structure(node, prefix = nil)
    case node
    when Hash
      node.flat_map { |key, value| structure(value, prefix ? "#{prefix}.#{key}" : key.to_s) }
    when Array
      node.flat_map { |value| structure(value, "#{prefix}[]") }.uniq
    else
      [ "#{prefix}:#{json_type(node)}" ]
    end
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
end
