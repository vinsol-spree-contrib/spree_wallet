require 'spec_helper'

describe Spree::Order do
  let!(:store) { Spree::Store.create!(mail_from_address: 'test@testmail.com', code: '1234', name: 'test', url: 'www.test.com') }
  let(:user) { Spree::User.create!(:email => 'test@testmail.com', :password => '123456') { |user| user.store_credits_total = 200 }}
  let(:order) { Spree::Order.create! { |order| order.user = user }}
  let(:wallet_payment_method) { Spree::PaymentMethod::Wallet.new(name: 'wallet') }
  let(:check_payment_method) { Spree::PaymentMethod::Check.new(name: 'check') }
  let(:available_payment_methods) { [wallet_payment_method, check_payment_method] }
  
  before(:each) do
    order.update_column(:total, 1000)
    order.update_column(:payment_total, 200)
    @shipping_category = Spree::ShippingCategory.create!(:name => 'test')
    @stock_location = Spree::StockLocation.create! :name => 'test' 
    @product = Spree::Product.create!(:name => "product", :price => 100) { |p| p.shipping_category = @shipping_category }
    @stock_item = @product.master.stock_items.first
    @stock_item.adjust_count_on_hand(10)
    @stock_item.save!

    order.line_items.create! :variant_id => @product.master.id, :quantity => 1
  end

  describe 'remaining_total' do
    subject { order.remaining_total }
    it { is_expected.to eq(order.total - order.payment_total) }
  end

  describe 'order cancel' do
    before(:each) do
      order.email = user.email
      @country = Spree::Country.where(:name => 'United States', :iso_name => 'US').first_or_create!
      @state = Spree::State.create!(:name => "Michigan", :abbr => "MI", :country => @country)
      @address = Spree::Address.create!(:firstname => 'first name', :lastname => 'lastname', :address1 => 'address1', :address2 => 'address2', :city => 'abcd', :state => @state, :country => @country, :phone => '1234', :zipcode => '123456')
      order.bill_address = order.ship_address = @address
      order.save!
      allow(order).to receive(:ensure_available_shipping_rates).and_return(true)
      check_payment_method.save!
      wallet_payment_method.save!
      @check_payment = order.payments.create!(:amount => 100, :payment_method_id => check_payment_method.id) { |p| p.state = 'checkout' }
      @wallet_payment = order.payments.create!(:amount => 100, :payment_method_id => wallet_payment_method.id) { |p| p.state = 'checkout' }
      order.next! until order.completed?
      @check_payment.complete!
      @payments = [@check_payment, @wallet_payment]
      allow(order).to receive(:payments).and_return(order.payments)
      allow(@payments).to receive(:with_state).and_return(@payments)
      allow(@payments).to receive(:reload).and_return(@payments)
      allow(@payments).to receive(:exists?).and_return(@payments)
      allow(@payments).to receive(:completed).and_return(@payments)
      allow(@payments).to receive(:where).with(:payment_method_id => Spree::PaymentMethod::Wallet.pluck(:id)).and_return([@wallet_payment])
    end

    it 'should_receive make_wallet_payments_void' do
      expect(order).to receive(:make_wallet_payments_void).and_return(true)
      order.cancel!
    end

    describe 'make_wallet_payments_void' do
      it 'should not make other than wallet_payments void' do
        order.cancel!
        expect(@check_payment).not_to be_void
      end

      it 'should make wallet_payments void' do
        order.cancel!
        expect(@wallet_payment).not_to be_void
      end
    end

    describe 'wallet_payments' do
      it 'should give only wallet_payments' do
        expect(order.send(:wallet_payments)).to eq([@wallet_payment])
      end

      it 'should receive payments and return @payments' do
        expect(order).to receive(:payments).and_return(@payments)
        order.send(:wallet_payments)
      end

      it 'should receive where on payments' do
        expect(order.payments).to receive(:where).with(:payment_method_id => Spree::PaymentMethod::Wallet.pluck(:id)).and_return(@payments)
        order.send(:wallet_payments)
      end
    end
  end

  describe 'available_wallet_payment_amount' do
    subject { order.available_wallet_payment_amount }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end

      it { is_expected.to eq(user.store_credits_total) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { is_expected.to eq(order.remaining_total) }
    end
  end

  describe 'remaining_total_after_wallet' do
    subject { order.remaining_total_after_wallet }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end

      it { is_expected.to eq(order.remaining_total - user.store_credits_total) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { is_expected.to eq(0.0) }
    end
  end

  describe 'display_available_wallet_payment_amount' do
    subject { order.display_available_wallet_payment_amount.to_html }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end
      
      it { is_expected.to eq(Spree::Money.new(user.store_credits_total).to_html) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { is_expected.to eq(Spree::Money.new(order.remaining_total).to_html) }
    end
  end

  describe 'display_remaining_total_after_wallet' do
    subject { order.display_remaining_total_after_wallet.to_html }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end
      
      it { is_expected.to eq(Spree::Money.new(order.remaining_total - user.store_credits_total).to_html) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { is_expected.to eq(Spree::Money.new(0.0).to_html) }
    end
  end

  describe 'other_than_wallet_payment_required?' do
    subject { order.other_than_wallet_payment_required? }
    context 'when order remaining total > store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end

      it { is_expected.to be_truthy }
    end

    context 'when order remaining total < store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { is_expected.to be_falsey }
    end

    context 'when order remaining total = store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total
        user.save!
      end

      it { is_expected.to be_falsey }
    end
  end

  describe '#user_or_by_email' do
    subject { order.user_or_by_email }
    let(:user1) { Spree::User.create!(:email => 'test123@testmail.com', :password => '123456') { |user| user.store_credits_total = 200 } }

    context 'if order has user' do
      it { is_expected.to eq(user) }

      it 'should not receive where with :email => user.email' do
        expect(Spree::User).not_to receive(:where).with(:email => user1.email)
        order.user_or_by_email
      end

      it 'should receive user twice and return user' do
        expect(order).to receive(:user).twice.and_return(user)
        order.user_or_by_email
      end
    end

    context 'when order has no user' do
      before(:each) do
        order.email = user1.email
        order.save!
        allow(Spree::User).to receive(:where).with(:email => user1.email).and_return([user1])
        allow(order).to receive(:user).and_return(nil)
      end

      it { is_expected.to eq(user1) }

      it 'should not receive where with :email => user.email' do
        expect(Spree::User).to receive(:where).with(:email => user1.email).and_return([user1])
        order.user_or_by_email
      end

      it 'should receive user only once and return nil' do
        expect(order).to receive(:user).and_return(nil)
        order.user_or_by_email
      end
    end
  end

  describe 'has_unprocessed_payments?' do
    let(:wallet_payment) { Spree::Payment.new(:amount => 200) }
    let(:check_payment) { Spree::Payment.new(:amount => 100) }
    let(:wallet_payments) { [wallet_payment] }
    let(:check_payments) { [check_payment] }
    let(:empty_payments) { [] }

    subject { order }

    before(:each) do
      wallet_payment.payment_method = wallet_payment_method
      check_payment.payment_method = check_payment_method
    end

    context 'when has_unprocessed_payments' do
      let(:payments) { [wallet_payment, check_payment] }
      
      before(:each) do
        wallet_payment.order = order
        check_payment.order = order
        check_payment.save!
        order.update_column(:total, 1000)
        order.update_column(:payment_total, 200)
        wallet_payment.save!
        allow(order).to receive(:payments).and_return(payments)
        allow(payments).to receive(:with_state).and_return(check_payments)
        allow(check_payments).to receive(:reload).and_return(check_payments)
        allow(check_payments).to receive(:exists?).and_return(true)
      end

      it { is_expected.to have_unprocessed_payments }

      it 'should receive payments and return payments' do
        expect(order).to receive(:payments).and_return(payments)
        order.has_unprocessed_payments?
      end

      it 'should receive with_state and return wallet_payment' do
        expect(payments).to receive(:with_state).with('checkout').and_return(check_payments)
        order.has_unprocessed_payments?
      end

      it 'should not receive available_wallet_payment_method and return wallet_payment_method' do
        expect(order).not_to receive(:available_wallet_payment_method)
        order.has_unprocessed_payments?
      end

      it 'should not receive where with payment_method_id => wallet_payment_method.id' do
        expect(wallet_payments).not_to receive(:where).with(:payment_method_id => wallet_payment_method.id)
        order.has_unprocessed_payments?
      end
    end

    context 'when has no unprocessed_payments' do
      context 'has no wallet_payment_method' do
        before(:each) do
          user.store_credits_total = 1000
          user.save!
          wallet_payment.amount = order.remaining_total
          wallet_payment.order = order
          wallet_payment.save!
          order.update_column(:total, 1000)
          order.update_column(:payment_total, 200)
          allow(order).to receive(:payments).and_return(wallet_payments)
          allow(wallet_payments).to receive(:where).and_return(wallet_payments)
          allow(wallet_payments).to receive(:with_state).and_return(empty_payments)
          allow(empty_payments).to receive(:reload).and_return(empty_payments)
          allow(empty_payments).to receive(:exists?).and_return(false)
          allow(order).to receive(:available_wallet_payment_method).and_return(nil)
        end

        it { is_expected.not_to have_unprocessed_payments }

        it 'should receive payments and return payments' do
          expect(order).to receive(:payments).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive with_state and return wallet_payment' do
          expect(wallet_payments).to receive(:with_state).with('checkout').and_return(empty_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive available_wallet_payment_method and return nil' do
          expect(order).to receive(:available_wallet_payment_method).and_return(nil)
          order.has_unprocessed_payments?
        end

        it 'should receive where with payment_method_id => wallet_payment_method.id' do
          expect(wallet_payments).not_to receive(:where)
          order.has_unprocessed_payments?
        end
      end

      context 'wallet_payment.amount == remaining_total' do
        before(:each) do
          user.store_credits_total = 1000
          user.save!
          wallet_payment.amount = order.remaining_total
          wallet_payment.order = order
          wallet_payment.save!
          order.update_column(:total, 1000)
          order.update_column(:payment_total, 200)
          allow(order).to receive(:payments).and_return(wallet_payments)
          allow(wallet_payments).to receive(:where).and_return(wallet_payments)
          allow(wallet_payments).to receive(:with_state).and_return(empty_payments)
          allow(empty_payments).to receive(:reload).and_return(empty_payments)
          allow(empty_payments).to receive(:exists?).and_return(false)
          allow(order).to receive(:available_wallet_payment_method).and_return(wallet_payment_method)
        end

        it { is_expected.to have_unprocessed_payments }

        it 'should receive payments and return payments' do
          expect(order).to receive(:payments).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive with_state and return wallet_payment' do
          expect(wallet_payments).to receive(:with_state).with('checkout').and_return(empty_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive available_wallet_payment_method and return wallet_payment_method' do
          expect(order).to receive(:available_wallet_payment_method).and_return(wallet_payment_method)
          order.has_unprocessed_payments?
        end

        it 'should receive where with payment_method_id => wallet_payment_method.id' do
          expect(wallet_payments).to receive(:where).with(:payment_method_id => wallet_payment_method.id).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end
      end

      context 'wallet_payment.amount != remaining_total' do
        before(:each) do
          user.store_credits_total = 1000
          user.save!
          wallet_payment.amount = order.remaining_total - 200
          wallet_payment.order = order
          wallet_payment.save!
          allow(order).to receive(:payments).and_return(wallet_payments)
          allow(wallet_payments).to receive(:where).and_return(wallet_payments)
          allow(wallet_payments).to receive(:with_state).and_return(empty_payments)
          allow(empty_payments).to receive(:reload).and_return(empty_payments)
          allow(empty_payments).to receive(:exists?).and_return(false)
          allow(order).to receive(:available_wallet_payment_method).and_return(wallet_payment_method)
        end

        it { is_expected.not_to have_unprocessed_payments }

        it 'should receive payments and return payments' do
          expect(order).to receive(:payments).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive with_state and return wallet_payment' do
          expect(wallet_payments).to receive(:with_state).with('checkout').and_return(empty_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive available_wallet_payment_method and return wallet_payment_method' do
          expect(order).to receive(:available_wallet_payment_method).and_return(wallet_payment_method)
          order.has_unprocessed_payments?
        end

        it 'should receive where with payment_method_id => wallet_payment_method.id' do
          expect(wallet_payments).to receive(:where).with(:payment_method_id => wallet_payment_method.id).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end
      end
    end
  end

  describe 'available_payment_methods_without_wallet' do
    before(:each) do
      allow(order).to receive(:available_payment_methods).and_return(available_payment_methods)
    end

    subject { order.available_payment_methods_without_wallet }

    it 'should receive available_payment_methods and return available_payment_methods' do
      expect(order).to receive(:available_payment_methods).and_return(available_payment_methods)
      order.available_payment_methods_without_wallet
    end

    it { is_expected.to eq([check_payment_method]) }
  end

  describe 'available_wallet_payment_method' do
    before(:each) do
      allow(order).to receive(:available_payment_methods).and_return(available_payment_methods)
    end

    subject { order.available_wallet_payment_method }

    it 'should receive available_payment_methods and return available_payment_methods' do
      expect(order).to receive(:available_payment_methods).and_return(available_payment_methods)
      order.available_wallet_payment_method
    end

    it { is_expected.to eq(wallet_payment_method) }
  end
end
