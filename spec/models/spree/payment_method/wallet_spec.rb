require 'spec_helper'

describe Spree::PaymentMethod::Wallet do

  let(:user) { Spree::User.create!(:email => 'abc@test.com', :password => '123456') }
  let(:wallet_payment_method) { Spree::PaymentMethod::Wallet.create!(:environment => Rails.env, :active => true, :name => 'Pay On Delivery') }
  let(:order) { Spree::Order.new }
  let(:payment) { Spree::Payment.new(:amount => 0.0) }

  before(:each) do    
    payment.order = order
    order.user = user
    payment.payment_method = wallet_payment_method
    payment.save!
  end
  
  describe 'actions' do
    it 'should return actions' do
      wallet_payment_method.actions.should eq(['void'])
    end
  end
  
  describe 'can_void?' do
    context 'when payment state is not void' do
      before(:each) do
        payment.state = 'pending'
        payment.save!
      end

      it 'should return true if payment can be void' do
        wallet_payment_method.can_void?(payment).should eq(true)
      end
    end

    context 'when payment state is void' do
      before(:each) do
        payment.state = 'void'
        payment.save!
      end

      it 'should return true if payment can be void' do
        wallet_payment_method.can_void?(payment).should eq(false)
      end
    end
  end

  describe 'void' do
    it 'should be a new ActiveMerchant::Billing::Response' do
      wallet_payment_method.void.should be_a(ActiveMerchant::Billing::Response)
    end

    it 'should receive new on ActiveMerchant::Billing::Response with true, "", {}, {}' do
      ActiveMerchant::Billing::Response.should_receive(:new).with(true, "", {}, {}).and_call_original
      wallet_payment_method.void
    end
  end
  
  describe 'source_required?' do
    it 'should return false' do
      wallet_payment_method.should_not be_source_required
    end
  end
end