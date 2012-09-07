$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'rubygems'
require 'bundler'
Bundler.setup :default, :test
require 'fragrant'
require 'rack/test'
require 'fileutils'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  config.before do
    FileUtils.mkdir_p(Fragrant.env_dir)
  end
end
