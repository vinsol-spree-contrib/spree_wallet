SpreeWallet  [![Code Climate](https://codeclimate.com/github/vinsol/spree_wallet.png)](https://codeclimate.com/github/vinsol/spree_wallet)
===========

Installation
------------

Add spree_wallet to your Gemfile:

```ruby
gem 'spree_wallet', '~> 2.0.6'
```

Bundle your dependencies and run the installation generator:

```shell
bundle
bundle exec rails g spree_wallet:install
bundle exec rake db:migrate
```

Usage
-----

From Admin end, create a payment method of Wallet type. From User end, user can only select or unselect wallet payment type. Spree Wallet will deduce minimum of order total and spree wallet balance of that user. If there's any remaining amount in the order it will be deducted from other payment method choosen by the user.

While from admin end, Admin can select any amount from wallet, but it should be less than amount present in user's balance. 

Testing
-------

You need to do a quick one-time creation of a test application and then you can use it to run the tests.

    bundle exec rake test_app

Then run the rspec tests with mysql.

    bundle exec rspec .



Credits
-------

[![vinsol.com: Ruby on Rails, iOS and Android developers](http://vinsol.com/vin_logo.png "Ruby on Rails, iOS and Android developers")](http://vinsol.com)

Copyright (c) 2014 [vinsol.com](http://vinsol.com "Ruby on Rails, iOS and Android developers"), released under the New MIT License
