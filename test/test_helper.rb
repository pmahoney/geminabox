require "rubygems"
gem "bundler"
require "bundler/setup"

require_relative '../lib/geminabox'
require 'minitest/autorun'
require 'fileutils'
require 'test_support/gem_factory'
require 'test_support/geminabox_test_case'
require 'test_support/http_dummy'
require 'test_support/http_socket_error_dummy'

require 'capybara/mechanize'
require 'capybara/dsl'

require 'webmock/minitest'
WebMock.disable_net_connect!(:allow_localhost => true)

Capybara.default_driver = :mechanize
Capybara.app_host = "http://localhost"
module TestMethodMagic
  def test(test_name, &block)
    define_method "test_method: #{test_name} ", &block
  end
end

class Minitest::Test
  extend TestMethodMagic

  TEST_DATA_DIR="/tmp/geminabox-test-data"
  def clean_data_dir
    FileUtils.rm_rf(TEST_DATA_DIR)
    FileUtils.mkdir(TEST_DATA_DIR)
    Geminabox.data = TEST_DATA_DIR
  end

  def self.fixture(path)
    File.join(File.expand_path("../fixtures", __FILE__), path)
  end

  def fixture(*args)
    self.class.fixture(*args)
  end


  def silence_stream(stream)
    old_stream = stream.dup
    stream.reopen('/dev/null')
    stream.sync = true
    yield
  ensure
    stream.reopen(old_stream)
  end

  def silence
    silence_stream(STDERR) do
      silence_stream(STDOUT) do
        yield
      end
    end
  end

  # Gem::Specification starts with Bundler's gems, has post_reset_hook
  # from Bundler, and attempts to populate itself from
  # Gem.loaded_specs after a reset hence setting +all+ to non-nil
  # empty array.
  #
  # Without this, some specs are Bundler::StubSpecification, and
  # cannot be dumped:
  #
  #     1) Error:
  # IsApiRequestTest#test_method: test upload via api :
  # TypeError: can't dump hash with default proc
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/indexer.rb:142:in `dump'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/indexer.rb:142:in `block (2 levels) in build_marshal_gemspecs'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/specification.rb:895:in `block in each'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/specification.rb:894:in `each'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/indexer.rb:137:in `block in build_marshal_gemspecs'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems.rb:907:in `time'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/indexer.rb:136:in `build_marshal_gemspecs'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/indexer.rb:119:in `build_indicies'
  #     ruby-2.2.0-p0/lib/ruby/2.2.0/rubygems/indexer.rb:310:in `generate_index'
  #     geminabox/test/requests/is_api_request_test.rb:12:in `block in setup'
  #     geminabox/test/test_helper.rb:58:in `block (2 levels) in silence'
  #     geminabox/test/test_helper.rb:50:in `silence_stream'
  #     geminabox/test/test_helper.rb:57:in `block in silence'
  #     geminabox/test/test_helper.rb:50:in `silence_stream'
  #     geminabox/test/test_helper.rb:56:in `silence'
  #     geminabox/test/requests/is_api_request_test.rb:11:in `setup'
  def clear_gem_specification!
    Gem.post_reset_hooks.clear
    Gem::Specification.reset
    Gem::Specification.all = []
  end

  def inject_gems(&block)
    clear_gem_specification!
    silence do
      yield GemFactory.new(File.join(Geminabox.data, "gems"))
      Gem::Indexer.new(Geminabox.data).generate_index
    end
  end

end

