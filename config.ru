require 'rubygems'
lib_dir = File.expand_path("../lib", __FILE__)
$LOAD_PATH << lib_dir unless $LOAD_PATH.include?(lib_dir)
require 'fragrant'
run Fragrant::Frontend
