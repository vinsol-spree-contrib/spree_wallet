# encoding: UTF-8
Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_wallet'
  s.version     = '2.0.5'
  s.summary     = 'Add payment method wallet to spree'
  s.description = 'Add wallet payment method functionality to spree'
  s.required_ruby_version = '>= 1.9.3'

  s.author    = "Nishant 'CyRo' Tuteja"
  s.email     = 'info@vinsol.com'
  s.homepage  = 'https://github.com/vinsol/spree_wallet'
  s.license   = "MIT"

  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core'

  s.add_development_dependency 'capybara', '~> 2.1'
  s.add_development_dependency 'coffee-rails'
  s.add_development_dependency 'database_cleaner'
  s.add_development_dependency 'factory_girl', '~> 4.2'
  s.add_development_dependency 'ffaker'
  s.add_development_dependency 'rspec-rails',  '~> 2.13'
  s.add_development_dependency 'sass-rails'
  s.add_development_dependency 'selenium-webdriver'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'sqlite3'
end
