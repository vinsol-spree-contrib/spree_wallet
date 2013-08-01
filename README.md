SpreeWallet
===========

Introduction goes here.

Installation
------------

Add spree_wallet to your Gemfile:

```ruby
gem 'spree_wallet', :git => 'git://github.com/vinsol/spree_wallet.git'
```

Bundle your dependencies and run the installation generator:

```shell
bundle
bundle exec rails g spree_wallet:install
bundle exec rake db:migrate
```

Usage
-----

From Admin end create a payment method of Wallet type.

## Contribution

You need to do a quick one-time creation of a test application and then you can use it to run the tests.

    bundle exec rake test_app

Then run the rspec tests with mysql.

    bundle exec rspec .