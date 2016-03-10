require 'spec_helper'
require File.join( File.dirname(__FILE__), 'shared_examples/disable_negative_payment_mode_ability_spec')

describe Spree::Debit do
  let(:user) { Spree::User.create!(:email => 'abc@test.com', :password => '123456') }
  let(:debit) { Spree::Debit.new(:amount => 123, :reason => 'test reason', :payment_mode => 0) { |debit| debit.user = user }}

  describe 'constants' do
    describe 'PAYMENT_MODE' do
      it { expect(Spree::Debit::PAYMENT_MODE).to eq({ 'Order Purchase' => -1, 'Deduce' => 0 })}
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
          expect(debit.balance).not_to eq(store_credits_total - debit.amount.to_f)
        end

        it 'should not recieve effective_amount' do
          expect(debit).not_to receive(:effective_amount)
          debit.save
        end

        it 'should receive set_balance' do
          expect(debit).to receive(:set_balance).and_call_original
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
            expect(debit.balance).to eq(store_credits_total - debit.amount)
          end

          it 'should recieve effective_amount' do
            expect(debit).to receive(:effective_amount).and_return(debit.amount)
            debit.save
          end

          describe 'effective_amount' do
            context 'when it has no arguement' do
              it 'should return the negation of amount' do
                expect(debit.send(:effective_amount)).to eq(-debit.amount)
              end
            end

            context 'when it has arguement' do
              it 'should return the negation of value' do
                expect(debit.send(:effective_amount, 1000)).to eq(-1000)
              end
            end
          end

          it 'should receive set_balance' do
            expect(debit).to receive(:set_balance).and_call_original
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
        expect(debit.balance).not_to eq(user.store_credits_total - debit.amount)
      end

      it 'should not receive set_balance' do
        expect(debit).not_to receive(:set_balance).and_call_original
        debit.save!
      end
    end
  end
end