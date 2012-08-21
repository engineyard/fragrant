$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..'))

require 'rubygems'
require 'bundler'
Bundler.setup :default, :test
require 'fragrant'
require 'rack/test'

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
