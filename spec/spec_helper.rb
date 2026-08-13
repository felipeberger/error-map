RSpec.configure do |config|
  # Use the expect syntax only (disable `should`).
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # Use the new mock syntax only.
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Allow shared example groups to be shared across files.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Run failures first on re-runs.
  config.order = :random
  Kernel.srand config.seed
end
