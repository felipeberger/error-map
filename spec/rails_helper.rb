require "spec_helper"

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"

# Prevent database truncation if the environment is production.
abort("The Rails environment is running in production mode!") if Rails.env.production?

require "rspec/rails"
require "capybara/rspec"

# Add additional requires below this line. Rails is not loaded until this point!

RSpec.configure do |config|
  # Use fixtures from the standard Rails fixture directory.
  config.fixture_paths = [Rails.root.join("test/fixtures")]

  # Automatically mix in different behaviours to your tests based on their file
  # location — e.g., :type => :controller inferred from spec/controllers/
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Include Rails route helpers in request specs.
  config.include Rails.application.routes.url_helpers, type: :request

  # Wrap each example in a database transaction that is rolled back afterwards.
  config.use_transactional_fixtures = true
end
