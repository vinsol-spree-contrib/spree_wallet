describe Spree::Order do
  let(:user) { Spree::User.create!(:email => 'test@testmail.com', :password => '123456') { |user| user.store_credits_total = 200 }}
  let(:order) { Spree::Order.create! { |order| order.user = user }}
  let(:wallet_payment_method) { Spree::PaymentMethod::Wallet.new }
  let(:check_payment_method) { Spree::PaymentMethod::Check.new }
  let(:available_payment_methods) { [wallet_payment_method, check_payment_method] }
  
  before(:each) do
    order.update_column(:total, 1000)
    order.update_column(:payment_total, 200)
  end

  describe 'remaining_total' do
    subject { order.remaining_total }
    it { should eq(order.total - order.payment_total) }
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