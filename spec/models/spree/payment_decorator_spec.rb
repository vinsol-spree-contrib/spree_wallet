require "spec_helper"

describe Spree::Payment do
  let(:user) { Spree::User.create!(:email => 'test@testmail.com', :password => '123456') { |user| user.store_credits_total = 1000 }}
  let(:order) { Spree::Order.create! { |order| order.user = user }}
  let(:wallet_payment_method) { Spree::PaymentMethod::Wallet.new }
  let(:check_payment_method) { Spree::PaymentMethod::Check.new }
  let(:wallet_payment) { Spree::Payment.new(:amount => 200) { |payment| payment.order = order } }
  let(:check_payment) { Spree::Payment.new(:amount => 300) { |payment| payment.order = order } }

  before(:each) do
    wallet_payment.payment_method = wallet_payment_method
    check_payment.payment_method = check_payment_method
    order.update_column(:total, 1000)
    order.update_column(:payment_total, 200)
  end

  describe '#wallet?' do
    context 'wallet_payment_method' do
      it { expect(wallet_payment.send(:wallet?)).to eq(true) }
    end

    context 'not wallet_payment_method' do
      it { expect(check_payment.send(:wallet?)).to eq(false) }
    end
  end

  describe '#order_user_or_by_email' do
    subject { wallet_payment.order_user_or_by_email }
    let(:user1) { Spree::User.create!(:email => 'test123@testmail.com', :password => '123456') { |user| user.store_credits_total = 200 } }

    context 'if order has user' do
      it { is_expected.to eq(user) }
    end

    context 'when order has no user' do
      before(:each) do
        order.email = user1.email
        order.save!
        allow(Spree::User).to receive(:where).with(:email => user1.email).and_return([user1])
        allow(order).to receive(:user).and_return(nil)
      end

      it { is_expected.to eq(user1) }
    end
  end

  describe '#consume_user_credits' do
    before do
      wallet_payment.amount = 100
    end
    it 'creates debit' do
      debit_store_credits_count = Spree::Debit.where(user: user).count
      wallet_payment.send(:consume_user_credits)
      expect(debit_store_credits_count).not_to eq Spree::Debit.where(user: user).count
    end
  end

  describe '#release_user_credits' do
    before do
      wallet_payment.amount = 100
    end
    it 'creates debit' do
      credit_store_credits_count = Spree::Credit.where(user: user).count
      wallet_payment.send(:release_user_credits)
      expect(credit_store_credits_count).not_to eq Spree::Credit.where(user: user).count
    end
  end

  describe '#debit_store_credits' do
    it 'creates debit' do
      debit_store_credits_count = Spree::Debit.where(user: user).count
      wallet_payment.send(:debit_store_credits, 100)
      expect(debit_store_credits_count).not_to eq Spree::Debit.where(user: user).count
    end
  end

  describe '#credit_store_credits' do
    it 'creates debit' do
      debit_store_credits_count = Spree::Credit.where(user: user).count
      wallet_payment.send(:credit_store_credits, 100)
      expect(debit_store_credits_count).not_to eq Spree::Credit.where(user: user).count
    end
  end

  describe '#calculate_balance' do
    it 'returns balance' do
      balance = wallet_payment.send(:calculate_balance, 100)
      expect(balance).to eq user.store_credits_total - 100
    end
  end

  describe 'validation' do
    context 'not wallet_payment' do
      subject { check_payment }
      context 'amount_changed?' do
        it { is_expected.to validate_numericality_of(:amount).is_less_than_or_equal_to(check_payment.order_remaining_total.to_f) }
      end

      context 'amount_not_changed' do
        it 'should have no error on amount' do
          check_payment.save
          expect(check_payment.errors[:amount]).to eq([])
        end
      end
    end

    context 'wallet_payment' do
      subject { wallet_payment }

      context 'when amount_changed? and has order_user_or_by_email' do
        context 'when payment.order_remaining_total is min' do
          it { is_expected.to validate_numericality_of(:amount).is_less_than_or_equal_to(wallet_payment.order_remaining_total.to_f) }
        end

        context 'when user.store_credits_total is min' do
          before(:each) do
            user.store_credits_total = wallet_payment.order_remaining_total - 100
            user.save!
            wallet_payment.save!
          end

          it { is_expected.to validate_numericality_of(:amount).is_less_than_or_equal_to(user.store_credits_total) }
        end 
      end
    end

    context 'amount_not_changed' do
      it 'should have no error on amount' do
        wallet_payment.save
        expect(wallet_payment.errors[:amount]).to eq([])
      end
    end

    context 'no order_user_or_by_email' do
      before(:each) do
        allow(wallet_payment).to receive(:order_user_or_by_email).and_return(nil)
      end

      it 'should have no error on amount' do
        wallet_payment.save
        expect(wallet_payment.errors[:amount]).to eq([])
      end
    end

    describe 'restrict_wallet_when_no_user' do
      context 'when no wallet' do
        it 'should have no errors on base' do
          check_payment.save
          expect(check_payment.errors[:base]).to eq([])
        end
      end

      context 'when order_user_or_by_email' do
        it 'should have no errors on base' do
          wallet_payment.save
          expect(wallet_payment.errors[:base]).to eq([])
        end
      end

      context 'when wallet and no order_user_or_by_email' do
        before(:each) do
          allow(wallet_payment).to receive(:order_user_or_by_email).and_return(nil)
        end

        it 'should have errors on base' do
          wallet_payment.save
          expect(wallet_payment.errors[:base]).to eq([Spree.t(:wallet_not_linked_to_user)])
        end
      end
    end
  end

  describe 'callback' do
    describe 'after_create complete!' do
      context 'wallet_payment' do
        it 'should receive complete!' do
          expect(wallet_payment).to receive(:complete!).and_return(true)
          wallet_payment.save!
        end
      end

      context 'non_wallet_payment' do
        it 'should not receive complete!' do
          expect(check_payment).not_to receive(:complete!)
          check_payment.save!
        end
      end
    end
  end

  describe 'state_machine' do
    describe 'consume_wallet_credit' do
      context 'wallet_payment' do
        it 'should receive consume_user_credits' do
          expect(wallet_payment).to receive(:consume_user_credits).and_return(true)
          wallet_payment.save!
        end

        it 'should create a debit' do
          wallet_payment.save!
          expect(user.store_credits.last).to be_a(Spree::Debit)
        end

        it 'should create a debit of payment amount' do
          wallet_payment.save!
          expect(user.store_credits.last.amount).to eq(wallet_payment.amount)
        end

        it 'should create a debit of payment_mode Order Purchase' do
          wallet_payment.save!
          expect(user.store_credits.last.payment_mode).to eq(Spree::Debit::PAYMENT_MODE['Order Purchase'])
        end

        it 'should create a debit of reason Payment consumed of order number' do
          wallet_payment.save!
          expect(user.store_credits.last.reason).to eq("Payment consumed for order #{order.number}")
        end
      end

      context 'not wallet_payment' do
        it 'should not receive consume_user_credits' do
          expect(check_payment).not_to receive(:consume_user_credits)
          check_payment.save!
        end
      end
    end

    describe 'release_user_credits' do
      context 'wallet_payment' do
        before(:each) do
          wallet_payment.save!
          order.update_column(:total, 1000)
          order.update_column(:payment_total, 200)
        end

        it 'should receive consume_user_credits' do
          expect(wallet_payment).to receive(:release_user_credits).and_return(true)
          wallet_payment.void!
        end

        it 'should create a debit' do
          wallet_payment.void!
          expect(user.store_credits.last).to be_a(Spree::Credit)
        end

        it 'should create a debit of payment amount' do
          wallet_payment.void!
          expect(user.store_credits.last.amount).to eq(wallet_payment.amount)
        end

        it 'should create a debit of payment_mode Order Purchase' do
          wallet_payment.void!
          expect(user.store_credits.last.payment_mode).to eq(Spree::Credit::PAYMENT_MODE['Payment Refund'])
        end

        it 'should create a debit of reason Payment released of order number' do
          wallet_payment.void!
          expect(user.store_credits.last.reason).to eq("Payment released for order #{order.number}")
        end
      end

      context 'not wallet_payment' do
        it 'should not receive consume_user_credits' do
          expect(check_payment).not_to receive(:consume_user_credits)
          check_payment.save!
        end
      end
    end
  end
end
