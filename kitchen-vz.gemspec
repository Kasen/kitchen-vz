# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/vz_version'

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-vz'
  spec.version       = Kitchen::Driver::VZ_VERSION
  spec.authors       = ['Pavel Yudin']
  spec.email         = ['pyudin@parallels.com']
  spec.description   = 'A Virtuozzo driver for Test Kitchen'
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/Kasen/kitchen-vz'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = []
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'test-kitchen', '~> 1.5'
  spec.add_dependency 'net-ssh', '~> 3.0'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake'

  spec.add_development_dependency 'rubocop'
end
