require 'rubygems'
require 'bundler/setup'
require './fragrant'
worker = Fragrant.background_worker
at_exit do
  $stderr.puts "Waiting for any running Vagrant tasks to complete."
  worker[:shutdown] = true
  worker.join
end
run Fragrant::Frontend
