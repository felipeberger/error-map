# Base class for errors caused by malformed or unexpected data received
# from Datadog. Raised explicitly at the point where bad data is detected.
#
# Distinct from system errors (DB failures, network issues, bugs) which
# are unexpected StandardError subclasses. This distinction lets job rescue
# blocks react appropriately:
#   DatadogDataError → warn  (bad data; retrying won't help)
#   StandardError    → error (unexpected; should be investigated)
class DatadogDataError < StandardError
  # A required attribute was absent or blank in the Datadog event payload.
  class MissingAttributeError < DatadogDataError; end

  # The event structure was too malformed to process at all.
  class UnparsableEventError < DatadogDataError; end
end
