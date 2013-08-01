require 'spec_helper'
require 'models/spree/shared_examples/disable_negative_payment_mode_ability_spec'

describe Spree::Debit do
  let(:user) { Spree::User.create!(:email => 'abc@test.com', :password => '123456') }
  let(:debit) { Spree::Debit.new(:amount => 123, :reason => 'test reason', :payment_mode => 0) { |debit| debit.user = user }}

  describe 'constants' do
    describe 'PAYMENT_MODE' do
      it { Spree::Debit::PAYMENT_MODE.should eq({ 'Order Purchase' => -1, 'Deduce' => 0 })}
    end
  end

  it_should_behave_like 'disable_negative_payment_mode', Spree::Debit

  describe 'set_balance' do
    let(:store_credits_total) { 1000 }
    before(:each) do
      user.store_credits_total = store_credits_total
    end

    context 'on create' do
      shared_examples_for 'cannot_set_balance' do
        it 'should not update balance' do
          debit.save
          debit.balance.should_not eq(store_credits_total - debit.amount.to_f)
        end

        it 'should not recieve effective_amount' do
          debit.should_not_receive(:effective_amount)
          debit.save
        end

        it 'should receive set_balance' do
          debit.should_receive(:set_balance).and_call_original
          debit.save
        end
      end
      
      context 'when there is no user' do
        before(:each) do
          debit.user = nil
        end

        it_should_behave_like 'cannot_set_balance'
      end

      context 'when there is user' do
        context 'when there is no amount' do
          before(:each) do
            debit.amount = nil
          end

          it_should_behave_like 'cannot_set_balance'
        end

        context 'when there is amount' do
          it 'should update balance' do
            debit.save!
            debit.balance.should eq(store_credits_total - debit.amount)
          end

          it 'should recieve effective_amount' do
            debit.should_receive(:effective_amount).and_return(debit.amount)
            debit.save
          end

          describe 'effective_amount' do
            context 'when it has no arguement' do
              it 'should return the negation of amount' do
                debit.send(:effective_amount).should eq(-debit.amount)
              end
            end

            context 'when it has arguement' do
              it 'should return the negation of value' do
                debit.send(:effective_amount, 1000).should eq(-1000)
              end
            end
          end

          it 'should receive set_balance' do
            debit.should_receive(:set_balance).and_call_original
            debit.save!
          end
        end
      end
    end

    context 'on update' do
      before(:each) do
        debit.save!
        debit.reason = 'testing reason'
      end

      it 'should not update balance' do
        debit.save!
        debit.balance.should_not eq(user.store_credits_total - debit.amount)
      end

      it 'should not receive set_balance' do
        debit.should_not_receive(:set_balance).and_call_original
        debit.save!
      end
    end
  end
end