require 'spec_helper'

describe Spree.user_class do
  it { is_expected.to have_many(:store_credits).dependent(:destroy).class_name('Spree::StoreCredit') }
end
