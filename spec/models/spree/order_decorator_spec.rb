require 'spec_helper'

describe Spree::Order do
  let(:user) { Spree::User.create!(:email => 'test@testmail.com', :password => '123456') { |user| user.store_credits_total = 200 }}
  let(:order) { Spree::Order.create! { |order| order.user = user }}
  let(:wallet_payment_method) { Spree::PaymentMethod::Wallet.new }
  let(:check_payment_method) { Spree::PaymentMethod::Check.new }
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
    it { should eq(order.total - order.payment_total) }
  end

  describe 'order cancel' do
    before(:each) do
      order.email = user.email
      @country = Spree::Country.where(:name => 'United States', :iso_name => 'US').first_or_create!
      @state = Spree::State.create!({:name => "Michigan", :abbr => "MI", :country => @country}, :without_protection => true)
      @address = Spree::Address.create!({:firstname => 'first name', :lastname => 'lastname', :address1 => 'address1', :address2 => 'address2', :city => 'abcd', :state => @state, :country => @country, :phone => '1234', :zipcode => '123456'}, :without_protection => true)
      order.bill_address = order.ship_address = @address
      order.save!
      order.stub(:ensure_available_shipping_rates).and_return(true)

      @check_payment = order.payments.create!(:amount => 100, :payment_method_id => check_payment_method.id) { |p| p.state = 'checkout' }
      @wallet_payment = order.payments.create!(:amount => 100, :payment_method_id => wallet_payment_method.id) { |p| p.state = 'checkout' }
      order.next! until order.completed?
      @check_payment.complete!
      @payments = [@check_payment, @wallet_payment]
      order.stub(:payments).and_return(@payments)
      @payments.stub(:with_state).and_return(@payments)
      @payments.stub(:reload).and_return(@payments)
      @payments.stub(:exists?).and_return(@payments)
      @payments.stub(:completed).and_return(@payments)
      @payments.stub(:where).with(:payment_method_id => Spree::PaymentMethod::Wallet.pluck(:id)).and_return([@wallet_payment])
    end

    it 'should_receive make_wallet_payments_void' do
      order.should_receive(:make_wallet_payments_void).and_return(true)
      order.cancel!
    end

    describe 'make_wallet_payments_void' do
      it 'should not make other than wallet_payments void' do
        order.cancel!
        @check_payment.should_not be_void
      end

      it 'should make wallet_payments void' do
        order.cancel!
        @wallet_payment.should be_void
      end
    end

    describe 'wallet_payments' do
      it 'should give only wallet_payments' do
        order.send(:wallet_payments).should eq([@wallet_payment])
      end

      it 'should receive payments and return @payments' do
        order.should_receive(:payments).and_return(@payments)
        order.send(:wallet_payments)
      end

      it 'should receive where on payments' do
        @payments.should_receive(:where).with(:payment_method_id => Spree::PaymentMethod::Wallet.pluck(:id)).and_return(@payments)
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

      it { should eq(user.store_credits_total) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { should eq(order.remaining_total) }
    end
  end

  describe 'remaining_total_after_wallet' do
    subject { order.remaining_total_after_wallet }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end

      it { should eq(order.remaining_total - user.store_credits_total) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { should eq(0.0) }
    end
  end

  describe 'display_available_wallet_payment_amount' do
    subject { order.display_available_wallet_payment_amount.to_html }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end
      
      it { should eq(Spree::Money.new(user.store_credits_total).to_html) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { should eq(Spree::Money.new(order.remaining_total).to_html) }
    end
  end

  describe 'display_remaining_total_after_wallet' do
    subject { order.display_remaining_total_after_wallet.to_html }
    context 'when order has less remaining_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end
      
      it { should eq(Spree::Money.new(order.remaining_total - user.store_credits_total).to_html) }
    end
    context 'when order\'user has less store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { should eq(Spree::Money.new(0.0).to_html) }
    end
  end

  describe 'other_than_wallet_payment_required?' do
    subject { order.other_than_wallet_payment_required? }
    context 'when order remaining total > store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total - 100
        user.save!
      end

      it { should be_true }
    end

    context 'when order remaining total < store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total + 100
        user.save!
      end

      it { should be_false }
    end

    context 'when order remaining total = store_credits_total' do
      before(:each) do
        user.store_credits_total = order.remaining_total
        user.save!
      end

      it { should be_false }
    end
  end

  describe '#user_or_by_email' do
    subject { order.user_or_by_email }
    let(:user1) { Spree::User.create!(:email => 'test123@testmail.com', :password => '123456') { |user| user.store_credits_total = 200 } }

    context 'if order has user' do
      it { should eq(user) }

      it 'should not receive where with :email => user.email' do
        Spree::User.should_not_receive(:where).with(:email => user1.email)
        order.user_or_by_email
      end

      it 'should receive user twice and return user' do
        order.should_receive(:user).twice.and_return(user)
        order.user_or_by_email
      end
    end

    context 'when order has no user' do
      before(:each) do
        order.email = user1.email
        order.save!
        Spree::User.stub(:where).with(:email => user1.email).and_return([user1])
        order.stub(:user).and_return(nil)
      end

      it { should eq(user1) }

      it 'should not receive where with :email => user.email' do
        Spree::User.should_receive(:where).with(:email => user1.email).and_return([user1])
        order.user_or_by_email
      end

      it 'should receive user only once and return nil' do
        order.should_receive(:user).and_return(nil)
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
        order.stub(:payments).and_return(payments)
        payments.stub(:with_state).and_return(check_payments)
        check_payments.stub(:reload).and_return(check_payments)
        check_payments.stub(:exists?).and_return(true)
      end

      it { should have_unprocessed_payments }

      it 'should receive payments and return payments' do
        order.should_receive(:payments).and_return(payments)
        order.has_unprocessed_payments?
      end

      it 'should receive with_state and return wallet_payment' do
        payments.should_receive(:with_state).with('checkout').and_return(check_payments)
        order.has_unprocessed_payments?
      end

      it 'should not receive available_wallet_payment_method and return wallet_payment_method' do
        order.should_not_receive(:available_wallet_payment_method)
        order.has_unprocessed_payments?
      end

      it 'should not receive where with payment_method_id => wallet_payment_method.id' do
        wallet_payments.should_not_receive(:where).with(:payment_method_id => wallet_payment_method.id)
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
          order.stub(:payments).and_return(wallet_payments)
          wallet_payments.stub(:where).and_return(wallet_payments)
          wallet_payments.stub(:with_state).and_return(empty_payments)
          empty_payments.stub(:reload).and_return(empty_payments)
          empty_payments.stub(:exists?).and_return(false)
          order.stub(:available_wallet_payment_method).and_return(nil)
        end

        it { should_not have_unprocessed_payments }

        it 'should receive payments and return payments' do
          order.should_receive(:payments).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive with_state and return wallet_payment' do
          wallet_payments.should_receive(:with_state).with('checkout').and_return(empty_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive available_wallet_payment_method and return nil' do
          order.should_receive(:available_wallet_payment_method).and_return(nil)
          order.has_unprocessed_payments?
        end

        it 'should receive where with payment_method_id => wallet_payment_method.id' do
          wallet_payments.should_not_receive(:where)
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
          order.stub(:payments).and_return(wallet_payments)
          wallet_payments.stub(:where).and_return(wallet_payments)
          wallet_payments.stub(:with_state).and_return(empty_payments)
          empty_payments.stub(:reload).and_return(empty_payments)
          empty_payments.stub(:exists?).and_return(false)
          order.stub(:available_wallet_payment_method).and_return(wallet_payment_method)
        end

        it { should have_unprocessed_payments }

        it 'should receive payments and return payments' do
          order.should_receive(:payments).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive with_state and return wallet_payment' do
          wallet_payments.should_receive(:with_state).with('checkout').and_return(empty_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive available_wallet_payment_method and return wallet_payment_method' do
          order.should_receive(:available_wallet_payment_method).and_return(wallet_payment_method)
          order.has_unprocessed_payments?
        end

        it 'should receive where with payment_method_id => wallet_payment_method.id' do
          wallet_payments.should_receive(:where).with(:payment_method_id => wallet_payment_method.id).and_return(wallet_payments)
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
          order.stub(:payments).and_return(wallet_payments)
          wallet_payments.stub(:where).and_return(wallet_payments)
          wallet_payments.stub(:with_state).and_return(empty_payments)
          empty_payments.stub(:reload).and_return(empty_payments)
          empty_payments.stub(:exists?).and_return(false)
          order.stub(:available_wallet_payment_method).and_return(wallet_payment_method)
        end

        it { should_not have_unprocessed_payments }

        it 'should receive payments and return payments' do
          order.should_receive(:payments).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive with_state and return wallet_payment' do
          wallet_payments.should_receive(:with_state).with('checkout').and_return(empty_payments)
          order.has_unprocessed_payments?
        end

        it 'should receive available_wallet_payment_method and return wallet_payment_method' do
          order.should_receive(:available_wallet_payment_method).and_return(wallet_payment_method)
          order.has_unprocessed_payments?
        end

        it 'should receive where with payment_method_id => wallet_payment_method.id' do
          wallet_payments.should_receive(:where).with(:payment_method_id => wallet_payment_method.id).and_return(wallet_payments)
          order.has_unprocessed_payments?
        end
      end
    end
  end

  describe 'available_payment_methods_without_wallet' do
    before(:each) do
      order.stub(:available_payment_methods).and_return(available_payment_methods)
    end

    subject { order.available_payment_methods_without_wallet }

    it 'should receive available_payment_methods and return available_payment_methods' do
      order.should_receive(:available_payment_methods).and_return(available_payment_methods)
      order.available_payment_methods_without_wallet
    end

    it { should eq([check_payment_method]) }
  end

  describe 'available_wallet_payment_method' do
    before(:each) do
      order.stub(:available_payment_methods).and_return(available_payment_methods)
    end

    subject { order.available_wallet_payment_method }

    it 'should receive available_payment_methods and return available_payment_methods' do
      order.should_receive(:available_payment_methods).and_return(available_payment_methods)
      order.available_wallet_payment_method
    end

    it { should eq(wallet_payment_method) }
  end
end