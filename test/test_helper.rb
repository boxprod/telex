# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
ENV["LETTERMINT_WEBHOOK_SECRET"] = "whsec_test"
ENV["LETTERMINT_API_TOKEN"] = "lm_test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("../test/dummy/db/migrate", __dir__) ]
require "rails/test_help"
require "telex/test_helper"

ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures/files", __dir__)

# Answers from a hash of url => source instead of the network, or raises.
class FakeDownload
  attr_accessor :sources, :failure

  def initialize(sources = {})
    @sources = sources
  end

  def fetch(url)
    raise failure if failure
    sources.fetch(url)
  end
end

class ActiveSupport::TestCase
  include Telex::TestHelper

  setup { @download = Telex.download = FakeDownload.new }
  teardown { Telex.download = nil }
end
