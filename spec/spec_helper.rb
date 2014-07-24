require 'rspec'
require 'rspec/its'

require 'omnibus'
require 'fauxhai'

module Omnibus
  module RSpec
    SPEC_DATA = File.expand_path(File.join(File.dirname(__FILE__), 'data'))

    def overrides_path(name)
      File.join(SPEC_DATA, 'overrides', "#{name}.overrides")
    end

    def complicated_path
      File.join(SPEC_DATA, 'complicated')
    end

    def fixtures_path
      File.expand_path('../fixtures', __FILE__)
    end

    def tmp_path
      File.expand_path('../../tmp', __FILE__)
    end

    #
    # Stub the given environment key.
    #
    # @param [String] key
    # @param [String] value
    #
    def stub_env(key, value)
      unless @__env_already_stubbed__
        allow(ENV).to receive(:[]).and_call_original
        @__env_already_stubbed__ = true
      end

      allow(ENV).to receive(:[]).with(key).and_return(value.to_s)
    end

    #
    # Stub Ohai with the given data.
    #
    # @param [Hash] data
    #
    def stub_ohai(options = {}, &block)
      require 'ohai' unless defined?(Mash)

      ohai = Mash.from_hash(Fauxhai.mock(options, &block).data)
      allow(Ohai).to receive(:ohai).and_return(ohai)
    end

    #
    # Grab the result of the log command. Since Omnibus uses the block form of
    # the logger, this method handles both types of logging.
    #
    # @example
    #   output = capture_logging { some_command }
    #   expect(output).to include('whatever')
    #
    def capture_logging
      original = Omnibus.logger
      Omnibus.logger = TestLogger.new
      yield
      Omnibus.logger.output
    ensure
      Omnibus.logger = original
    end
  end
end

module Omnibus
  class TestLogger < Logger
    def initialize(*)
      super(StringIO.new)
      @level = -1
    end

    def output
      @logdev.dev.string
    end
  end
end

def windows?
  !!(RUBY_PLATFORM =~ /mswin|mingw|windows/)
end

def mac?
  !!(RUBY_PLATFORM =~ /darwin/)
end

RSpec.configure do |config|
  config.include Omnibus::RSpec
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.filter_run_excluding windows_only: true unless windows?
  config.filter_run_excluding mac_only: true unless mac?

  config.before(:each) do
    # Suppress logging
    Omnibus.logger.level = :unknown

    # Reset config
    Omnibus.reset!

    # Clear the tmp_path on each run
    FileUtils.rm_rf(tmp_path)
    FileUtils.mkdir_p(tmp_path)

    # Don't run Ohai - tests can still override this
    stub_ohai(platform: 'ubuntu', version: '12.04')
  end

  config.after(:each) do
    # Reset config
    Omnibus.reset!
  end

  # Force the expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in a random order
  config.order = 'random'
end

#
# Shard example group for asserting a DSL method
#
# @example
#   it_behaves_like 'a cleanroom setter', :name, <<-EOH
#     name 'foo'
#   EOH
#
RSpec.shared_examples 'a cleanroom setter' do |id, string|
  it "for `#{id}'" do
    expect { subject.evaluate(string) }
      .to_not raise_error
  end
end

#
# Shard example group for asserting a DSL method
#
# @example
#   it_behaves_like 'a cleanroom getter', :name
#
RSpec.shared_examples 'a cleanroom getter' do |id|
  it "for `#{id}'" do
    expect { subject.evaluate("#{id}") }.to_not raise_error
  end
end
