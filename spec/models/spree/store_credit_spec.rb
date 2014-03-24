require 'spec_helper'

RSpec.configure do |config|
  config.fixture_path = File.join( File.dirname(__FILE__ + '../'), 'fixtures')
end

describe Spree::StoreCredit do
  fixtures :spree_users
  set_fixture_class :spree_users => 'Spree::User'

  let(:user) { Spree::User.where(:email => 'abc@test.com').first_or_create! { |user| user.password = '123456' } }
  let(:store_credit) { Spree::Credit.new(:amount => 123, :reason => 'test reason', :payment_mode => 0) { |store_credit| store_credit.user = user }}

  subject { store_credit }

  describe 'order_created_at_desc' do
    let(:store_credit1) { Spree::Credit.create!(:amount => 123, :reason => 'test reason', :payment_mode => 0) { |store_credit| store_credit.user = user; store_credit.created_at = Time.current + 1.hour }}
    let(:store_credit2) { Spree::Credit.create!(:amount => 123, :reason => 'test reason', :payment_mode => 0) { |store_credit| store_credit.user = user; store_credit.created_at = Time.current }}

    it { Spree::StoreCredit.order_created_at_desc.should eq([store_credit1, store_credit2]) }
  end

  describe 'validations' do
    describe 'presence' do
      it { should validate_presence_of :amount }
      it { should validate_presence_of :user_id }
      it { should validate_presence_of :reason }
      it { should validate_presence_of :type }
      
      describe 'transaction_id and balance' do
        before(:each) do
          Spree::StoreCredit.any_instance.stub(:generate_transaction_id).and_return(true)
          store_credit.stub(:set_balance).and_return(true)
          Spree::StoreCredit.any_instance.stub(:update_user_wallet).and_return(true)
        end

        it { should validate_uniqueness_of :transaction_id }
        it { should validate_presence_of :transaction_id }
        it { should validate_presence_of :balance }
      end
    end

    describe 'numericality' do
      it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
      it { should validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }
    end
  end

  describe 'association' do
    it { should belong_to(:user).class_name(Spree.user_class) }
    it { should belong_to(:transactioner).class_name(Spree.user_class) }
  end

  describe 'callback' do
    describe 'update_user_wallet' do
      context 'on create' do
        it 'should update store_credits_total of user' do
          store_credit.save!
          user.store_credits_total.should eq(store_credit.balance)
        end

        it 'should receive update_user_wallet when create' do
          store_credit.should_receive(:update_user_wallet).and_return(true)
          store_credit.save!
        end
      end

      context 'on update' do
        before(:each) do
          store_credit.save!
          store_credit.reason = 'testing reason'
        end

        it 'should not receive update_user_wallet' do
          store_credit.should_not_receive(:update_user_wallet)
          store_credit.save!
        end
      end
    end
  end

  describe 'multiple request' do
    context 'concurrent' do      
      it 'should have 900 store_credits_total and 1 store_credit' do
        pending 'need to fix it with sqlite'
        @user = spree_users(:user1)
        config = ActiveRecord::Base.remove_connection

        pids = (1..5).to_a.enum_for(:each_with_index).collect do |i|
          fork do
            begin
              ActiveRecord::Base.establish_connection(config)
              id = Process.pid
              d = Spree::Debit.new(:amount => 100, :payment_mode => 0, :reason => 'kkkkk')
              d.user = @user
              d.save
            rescue ActiveRecord::StaleObjectError => e

            ensure
              ActiveRecord::Base.remove_connection
            end
          end
        end

        ActiveRecord::Base.establish_connection(config)

        pids.each {|pid| Process.waitpid pid}
        @user.reload.store_credits.count.should eq(1)
        @user.reload.store_credits_total.to_f.should eq(900.0)
      end
    end

    context 'not concurrent' do
      before(:each) do
        user.store_credits_total = 1000
        user.save!
        
        (1..5).to_a.each do
          d = Spree::Debit.new(:amount => 100, :payment_mode => 0, :reason => 'kkkkk')
          d.user = user
          d.save!
        end
      end

      it 'should have 500 store_credits_total' do
        user.reload.store_credits_total.to_f.should eq(500.0)
      end

      it 'should have 5 store_credits' do
        user.reload.store_credits.count.should eq(5)
      end
    end
  end

  describe 'generate_transaction_id' do
    context 'on create' do
      it 'should update transaction_id' do
        store_credit.save!
        store_credit.transaction_id.should_not eq(nil)
      end

      it 'should receive generate_transaction_id' do
        store_credit.should_receive(:generate_transaction_id).and_call_original
        store_credit.save!
      end

      context 'when transaction_id is unique' do
        before(:each) do
          Spree::StoreCredit.stub(:where).and_return([])
        end

        it 'should receive where on Spree::StoreCredit only once' do
          Spree::StoreCredit.should_receive(:where).and_return([])
          store_credit.save!
        end

        it 'should receive rand only once with 999999' do
          store_credit.should_receive(:rand).with(999999).and_return(1234)
          store_credit.save!
        end
      end

      context 'when transaction_id is not unique' do
        before(:each) do
          Spree::StoreCredit.stub(:where).and_return([store_credit], [])
        end

        it 'should receive where on Spree::StoreCredit only once' do
          Spree::StoreCredit.should_receive(:where).twice.and_return([store_credit], [])
          store_credit.save!
        end

        it 'should receive rand twice with 999999' do
          store_credit.should_receive(:rand).with(999999).twice.and_return(1234)
          store_credit.save!
        end
      end
    end

    context 'on update' do
      before(:each) do
        store_credit.save!
        store_credit.reason = 'testing reason'
      end

      it 'should not receive generate_transaction_id' do
        store_credit.should_not_receive(:generate_transaction_id)
        store_credit.save!
      end
    end
  end
end