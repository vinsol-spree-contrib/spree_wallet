require 'spec_helper'

describe Spree::PaymentMethod::Wallet do

  let(:user) { Spree::User.create!(:email => 'abc@test.com', :password => '123456') }
  let(:wallet_payment_method) { Spree::PaymentMethod::Wallet.create!(:active => true, :name => 'Pay On Delivery') }
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
      expect(wallet_payment_method.actions).to eq(['void', 'credit'])
    end
  end

  describe 'can_credit?' do
    context 'when payment amount is greater than 0' do
      before { payment.amount = 100 }
      it 'should return true' do
        expect(wallet_payment_method.can_credit?(payment)).to eq true
      end
    end

    context 'when payment amount is less than 0' do
      before { payment.amount = -100 }
      it 'should return false' do
        expect(wallet_payment_method.can_credit?(payment)).to eq false
      end
    end
  end

  describe 'can_void?' do
    context 'when payment state is not void' do
      before(:each) do
        payment.state = 'pending'
        payment.save!
      end

      it 'should return true if payment can be void' do
        expect(wallet_payment_method.can_void?(payment)).to eq(true)
      end
    end

    context 'when payment state is void' do
      before(:each) do
        payment.state = 'void'
        payment.save!
      end

      it 'should return true if payment can be void' do
        expect(wallet_payment_method.can_void?(payment)).to eq(false)
      end
    end

    context 'when payment state is invalid' do
      before(:each) do
        payment.state = 'invalid'
        payment.save!
      end

      it 'should return true if payment can be invalid' do
        expect(wallet_payment_method.can_void?(payment)).to eq(false)
      end
    end
  end

  describe 'void' do
    it 'should be a new ActiveMerchant::Billing::Response' do
      expect(wallet_payment_method.void).to be_a(ActiveMerchant::Billing::Response)
    end

    it 'should receive new on ActiveMerchant::Billing::Response with true, "", {}, {}' do
      expect(ActiveMerchant::Billing::Response).to receive(:new).with(true, "", {}, {}).and_call_original
      wallet_payment_method.void
    end
  end

  describe 'cancel' do
    it 'should be a new ActiveMerchant::Billing::Response' do
      expect(wallet_payment_method.cancel).to be_a(ActiveMerchant::Billing::Response)
    end

    it 'should receive new on ActiveMerchant::Billing::Response with true, "", {}, {}' do
      expect(ActiveMerchant::Billing::Response).to receive(:new).with(true, "", {}, {}).and_call_original
      wallet_payment_method.cancel
    end
  end

  describe 'source_required?' do
    it 'should return false' do
      expect(wallet_payment_method).not_to be_source_required
    end
  end
end
