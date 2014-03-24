# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_wallet'
  s.version     = '2.1.0'
  s.summary     = 'Add payment method wallet to spree'
  s.description = 'Add wallet payment method functionality to spree'
  s.required_ruby_version = '>= 1.9.3'
  s.files = Dir['LICENSE', 'README.md', 'app/**/*', 'config/**/*', 'lib/**/*', 'db/**/*']

  s.author    = "Nishant 'CyRo' Tuteja"
  s.email     = 'info@vinsol.com'
  s.homepage  = 'http://vinsol.com'
  s.license   = "MIT"

  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '~> 2.1.0'
end
