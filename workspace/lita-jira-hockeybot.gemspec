Gem::Specification.new do |spec|
  spec.name          = 'lita-jira'
  spec.version       = '0.1.0'
  spec.authors       = ['Stephen Copp']
  spec.description   = 'Lit bot to log JIRA tickets for hockey app crashes'
  spec.summary       = 'Add a summary'
  spec.homepage      = 'http://www.anki.com'
  spec.license       = 'Add a license'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = 'git ls-files'.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '>= 4.6.0'
  spec.add_runtime_dependency 'jira-ruby'
  spec.add_runtime_dependency 'curb'
  spec.add_runtime_dependency 'eventmachine'
  spec.add_runtime_dependency 'faraday'
  spec.add_runtime_dependency 'faye-websocket', '>= 0.8.0'
  spec.add_runtime_dependency 'multi_json'
  spec.add_runtime_dependency 'tzinfo'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'webmock',  '~> 1.24.6'
end
