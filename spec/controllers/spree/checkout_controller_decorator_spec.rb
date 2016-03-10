require 'spec_helper'

describe Spree::CheckoutController do
  let(:order) { mock_model(Spree::Order, :remaining_total => 1000, :state => 'payment') }
  let(:user) { mock_model(Spree::User, :store_credits_total => 500) }
  let(:wallet_payment_method) { mock_model(Spree::PaymentMethod::Wallet) }
  let(:check_payment_method) { mock_model(Spree::PaymentMethod::Check) }

  before(:each) do
    allow(user).to receive(:generate_spree_api_key!).and_return(true)
    allow(user).to receive(:last_incomplete_spree_order).and_return(nil)
    allow(order).to receive(:token).and_return(1000)
    allow(order).to receive(:update_from_params).and_return({})
    allow(order).to receive(:checkout_steps).and_return([])
  end

  describe '#update' do
    def send_request(params = {})
      put :update, params.merge!(:use_route => 'spree', :id => order.id)
    end

    before(:each) do
      allow(controller).to receive(:ensure_order_not_completed).and_return(true)
      allow(controller).to receive(:set_current_order).and_return(true)
      allow(controller).to receive(:ensure_checkout_allowed).and_return(true)
      allow(controller).to receive(:ensure_sufficient_stock_lines).and_return(true)
      allow(controller).to receive(:ensure_valid_state).and_return(true)
      allow(controller).to receive(:associate_user).and_return(true)
      allow(controller).to receive(:check_authorization).and_return(true)
      allow(controller).to receive(:current_order).and_return(order)
      allow(controller).to receive(:setup_for_current_state).and_return(true)
      allow(controller).to receive(:spree_current_user).and_return(user)
      allow(order).to receive(:has_checkout_step?).with("payment").and_return(true)
      allow(order).to receive(:payment?).and_return(true)
      allow(Spree::PaymentMethod::Wallet).to receive(:first).and_return(wallet_payment_method)
      allow(controller).to receive(:after_update_attributes).and_return(false)
      allow(order).to receive(:update_attributes).and_return(true)
      allow(order).to receive(:next).and_return(true)
      allow(order).to receive(:available_wallet_payment_method).and_return(wallet_payment_method)
      allow(order).to receive(:completed?).and_return(true)
      allow(order).to receive(:temporary_address=).and_return(true)
    end

    describe 'before_filter validate_payments' do
      shared_examples_for 'not_required_to_validate_payments' do
        subject { controller }
        before(:each) do
          send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
        end

        it { should_not_receive(:validate_payments) }
      end

      context 'when there is no order' do
        before(:each) do
          allow(controller).to receive(:current_order).and_return(nil)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'when checkout step is not payment' do
        before(:each) do
          allow(order).to receive(:has_checkout_step?).and_return(false)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'when order doesn\'t have any available_wallet_payment_method' do
        before(:each) do
          allow(order).to receive(:available_wallet_payment_method).and_return(nil)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'when order state is not payment' do
        before(:each) do
          allow(order).to receive(:payment?).and_return(false)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'order has payment state' do
        it 'should receive validate_payments' do
          expect(controller).to receive(:validate_payments).and_return(true)
          send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
        end

        shared_examples_for 'no_wallet_payment' do
          context 'when there is wallet_payment' do
            it 'should have flash error with message Spree.t(:cannot_select_wallet_while_guest_checkout)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              expect(flash[:error]).to eq(Spree.t(:cannot_select_wallet_while_guest_checkout))
            end

            it 'should redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              expect(response).to redirect_to checkout_state_path(order.state)
            end
          end

          context 'when there is no wallet_payment' do
            it 'should not have flash error with message Spree.t(:cannot_select_wallet_while_guest_checkout)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              expect(flash[:error]).not_to eq(Spree.t(:cannot_select_wallet_while_guest_checkout))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              expect(response).not_to redirect_to checkout_state_path(order.state)
            end
          end
        end

        context 'when there is no spree_current_user' do
          before(:each) do
            allow(controller).to receive(:spree_current_user).and_return(nil)
            allow(controller).to receive(:check_registration).and_return(true)
          end

          it_should_behave_like 'no_wallet_payment'
        end

        context 'when there is spree_current_user' do
          context 'when there is no wallet_payment' do
            it 'should not have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              expect(flash[:error]).not_to eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              expect(response).not_to redirect_to checkout_state_path(order.state)
            end
          end

          context 'when there are also other payment than wallet_payment' do
            it 'should not have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}, {:payment_method_id => wallet_payment_method.id}]})
              expect(flash[:error]).not_to eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}, {:payment_method_id => wallet_payment_method.id}]})
              expect(response).not_to redirect_to checkout_state_path(order.state)
            end
          end

          context 'when remainin total is less than user\'s store_credits_total' do
            before(:each) do
              allow(user).to receive(:store_credits_total).and_return(order.remaining_total + 200)
            end

            it 'should not have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              expect(flash[:error]).not_to eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              expect(response).not_to redirect_to checkout_state_path(order.state)
            end
          end

          context 'when there is only one wallet payment with remaining total less than store_credits_total' do
            before(:each) do
              allow(user).to receive(:store_credits_total).and_return(order.remaining_total - 200)
            end

            it 'should have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              expect(flash[:error]).to eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              expect(response).to redirect_to checkout_state_path(order.state)
            end
          end
        end
      end
    end

    describe 'object_params' do
      let(:source_params) { 'source_params' }
      let(:another_source_params) { 'another_source_params' }

      def send_request(params = {})
        put :update, params.merge!(:use_route => 'spree', :id => order.id)
      end

      context 'when validate_payments returns true' do

        before(:each) do
          allow(controller).to receive(:validate_payments).and_return(true)
        end

        it 'should receive has_checkout_step? with "payment" and return true' do
          expect(order).to receive(:has_checkout_step?).with("payment").and_return(true)
          send_request(:order => {})
        end

        it 'should receive payment? on order and return true' do
          expect(order).to receive(:payment?).and_return(true)
          send_request(:order => {})
        end
      end

      context 'when payment_source is present' do
        context 'when there are source_params' do
          it 'should assign it to first in payment_attributes' do
            send_request(:payment_source => { wallet_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            expect(controller.send(:params)[:order][:payments_attributes].first[:source_attributes]).to eq(another_source_params)
          end
        end

        context 'when there are no source_params' do
          it 'should not assign it to first in payment_attributes' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            expect(controller.send(:params)[:order][:payments_attributes].first[:source_attributes]).not_to eq(source_params)
          end

          it 'should have original value' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            expect(controller.send(:params)[:order][:payments_attributes].first[:source_attributes]).to eq(another_source_params)
          end
        end
      end

      context 'when payment_source is not present' do
        context 'when there are source_params' do
          it 'should assign it to first in payment_attributes' do
            send_request(:payment_source => { wallet_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            expect(controller.send(:params)[:order][:payments_attributes].first[:source_attributes]).to eq(another_source_params)
          end
        end

        context 'when there are no source_params' do
          it 'should not assign it to first in payment_attributes' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            expect(controller.send(:params)[:order][:payments_attributes].first[:source_attributes]).not_to eq(source_params)
          end

          it 'should have its original value' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            expect(controller.send(:params)[:order][:payments_attributes].first[:source_attributes]).to eq(another_source_params)
          end
        end

        describe 'payment' do
          context 'when spree_current_user and order has available_wallet_payment_method' do
            before(:each) do
              allow(controller).to receive(:spree_current_user).and_return(user)
            end

            it 'should_receive spree_current_user and return user' do
              expect(controller).to receive(:spree_current_user).and_return(user)
              send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
            end

            context 'only wallet_payment' do
              it 'should receive wallet_payment_attributes with params[:order][:payments_attributes] containing only payment_method_id' do
                expect(controller).to receive(:wallet_payment_attributes).exactly(2).with([ {"payment_method_id" => "#{wallet_payment_method.id}" }]).and_return([ {"payment_method_id" => "#{wallet_payment_method.id}" }])
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
              end

              context 'when order total is min' do
                before(:each) do
                  allow(order).to receive(:remaining_total).and_return(300)
                end

                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
                  expect(controller.send(:params)[:order][:payments_attributes].first[:payment_method_id]).to eq(wallet_payment_method.id.to_s)
                end
              end

              context 'when user store_credits_total is min' do
                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
                  expect(controller.send(:params)[:order][:payments_attributes].first[:payment_method_id]).to eq(wallet_payment_method.id.to_s)    
                end
              end
            end

            context 'only wallet_payment and other payment' do
              it 'should receive wallet_payment_attributes with params[:order][:payments_attributes]' do
                expect(controller).to receive(:wallet_payment_attributes).exactly(2).with([ {"payment_method_id" => "#{wallet_payment_method.id}" }, {"payment_method_id" => "#{check_payment_method.id}" }]).and_return([ {"payment_method_id" => "#{wallet_payment_method.id}" }])
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
              end

              it 'should receive non_wallet_payment_attributes' do
                expect(controller).to receive(:non_wallet_payment_attributes).exactly(1).with([ {"payment_method_id" => "#{wallet_payment_method.id}"}, { "payment_method_id" => "#{check_payment_method.id}" }]).and_return([{ :payment_method_id => check_payment_method.id }])
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
              end

              context 'when order total is min' do
                before(:each) do
                  allow(order).to receive(:remaining_total).and_return(300)
                end

                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
                  expect(controller.send(:params)[:order][:payments_attributes].first[:payment_method_id]).to eq(wallet_payment_method.id.to_s)
                end

                it 'should delete other payment from payments_attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
                  expect(controller.send(:params)[:order][:payments_attributes]).to eq([{"payment_method_id" => "#{wallet_payment_method.id}" }])
                end
              end

              context 'when user store_credits_total is min' do
                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, {:payment_method_id => check_payment_method.id}]})
                end

                it 'should not delete other payment' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, {:payment_method_id => check_payment_method.id}]})
                  expect(controller.send(:params)[:order][:payments_attributes].second[:payment_method_id]).to eq(check_payment_method.id.to_s)
                end

                it 'should set remaining amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, {:payment_method_id => check_payment_method.id}]})
                end
              end
            end

            context 'no wallet_payment' do
              it 'should set amount in wallet payment attributes' do
                send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
                expect(controller.send(:params)[:order][:payments_attributes].first[:payment_method_id]).to eq(check_payment_method.id.to_s)
              end
            end
          end

          shared_examples_for 'not_make_wallet_payment' do
            before(:each) do
              allow(controller).to receive(:non_wallet_payment_attributes).with([{:payment_method_id => check_payment_method.id.to_s}]).and_return('test')
              allow(controller).to receive(:wallet_payment_attributes).with([{:payment_method_id => check_payment_method.id.to_s}]).and_return('test')
            end

            it 'should receive spree_current_user and return nil' do
              expect(controller).to receive(:spree_current_user).and_return(nil)
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
            end

            it 'should set payment_attributes first with amount' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              expect(controller.send(:params)[:order][:payments_attributes].first[:payment_method_id]).to eq(check_payment_method.id.to_s)
            end
          end

          context 'when no available_wallet_payment_method' do
            before(:each) do
              allow(controller).to receive(:check_registration).and_return(true)
              allow(order).to receive(:remaining_total).and_return(1000)
              allow(order).to receive(:available_wallet_payment_method).and_return(wallet_payment_method)
            end

            it_should_behave_like 'not_make_wallet_payment'
          end
        end
      end
    end
  end
end
