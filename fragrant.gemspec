lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |s|
  s.name        = 'fragrant'
  s.version     = "0.0.5"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Matt Whiteley']
  s.email       = ['mwhiteley@engineyard.com']
  s.homepage    = 'http://github.com/engineyard/fragrant/'
  s.summary     = 'An HTTP API for Vagrant'
  s.description = 'Generate and manage Vagrant boxes remotely'

  s.required_ruby_version = '>= 1.8.7'
  s.add_dependency 'vagrant'
  s.add_dependency 'uuid'
  s.add_dependency 'puma'
  s.add_dependency 'vegas'
  s.add_dependency 'grape', "~> 0.2.1" # vendorized, though
  s.add_dependency 'virtus' # vendorized grape requires this, released 0.2.1 does not yet

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rack-test'

  s.require_path = 'lib'
  s.executables  = ['fragrant']
  s.files        = Dir.glob('{bin,lib,vendor,templates}/**/*') + %w(LICENSE README.md)
  s.test_files   = Dir.glob('{spec}/**/*') + %w(Rakefile Gemfile Gemfile.lock)
end
