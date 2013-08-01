require 'spec_helper'

describe Spree::CheckoutController do
  let(:order) { mock_model(Spree::Order, :remaining_total => 1000, :state => 'payment') }
  let(:user) { mock_model(Spree::User, :store_credits_total => 500) }
  let(:wallet_payment_method) { mock_model(Spree::PaymentMethod::Wallet) }
  let(:check_payment_method) { mock_model(Spree::PaymentMethod::Check) }

  before(:each) do  
    user.stub(:generate_spree_api_key!).and_return(true)
    user.stub(:last_incomplete_spree_order).and_return(nil)
    order.stub(:token).and_return(1000)
  end

  describe '#update' do
    def send_request(params = {})
      put :update, params.merge!(:use_route => 'spree', :id => order.id)
    end

    before(:each) do
      controller.stub(:ensure_order_not_completed).and_return(true)
      controller.stub(:ensure_checkout_allowed).and_return(true)
      controller.stub(:ensure_sufficient_stock_lines).and_return(true)
      controller.stub(:ensure_valid_state).and_return(true)
      controller.stub(:associate_user).and_return(true)
      controller.stub(:check_authorization).and_return(true)
      controller.stub(:current_order).and_return(order)  
      controller.stub(:setup_for_current_state).and_return(true)
      controller.stub(:spree_current_user).and_return(user)
      order.stub(:has_checkout_step?).with("payment").and_return(true)
      order.stub(:payment?).and_return(true)
      Spree::PaymentMethod::Wallet.stub(:first).and_return(wallet_payment_method)
      controller.stub(:after_update_attributes).and_return(false)
      order.stub(:update_attributes).and_return(true)
      order.stub(:next).and_return(true)
      order.stub(:available_wallet_payment_method).and_return(wallet_payment_method)
      order.stub(:completed?).and_return(true)
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
          controller.stub(:current_order).and_return(nil)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'when checkout step is not payment' do
        before(:each) do
          order.stub(:has_checkout_step?).and_return(false)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'when order doesn\'t have any available_wallet_payment_method' do
        before(:each) do
          order.stub(:available_wallet_payment_method).and_return(nil)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'when order state is not payment' do
        before(:each) do
          order.stub(:payment?).and_return(false)
        end

        it_should_behave_like 'not_required_to_validate_payments'
      end

      context 'order has payment state' do
        it 'should receive validate_payments' do
          controller.should_receive(:validate_payments).and_return(true)
          send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
        end

        shared_examples_for 'no_wallet_payment' do
          context 'when there is wallet_payment' do
            it 'should have flash error with message Spree.t(:cannot_select_wallet_while_guest_checkout)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              flash[:error].should eq(Spree.t(:cannot_select_wallet_while_guest_checkout))
            end

            it 'should redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              response.should redirect_to checkout_state_path(order.state)
            end
          end

          context 'when there is no wallet_payment' do
            it 'should not have flash error with message Spree.t(:cannot_select_wallet_while_guest_checkout)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              flash[:error].should_not eq(Spree.t(:cannot_select_wallet_while_guest_checkout))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              response.should_not redirect_to checkout_state_path(order.state)
            end
          end
        end

        context 'when there is no spree_current_user' do
          before(:each) do
            controller.stub(:spree_current_user).and_return(nil)
            controller.stub(:check_registration).and_return(true)
          end

          it_should_behave_like 'no_wallet_payment'
        end

        context 'when there is spree_current_user' do
          context 'when there is no wallet_payment' do
            it 'should not have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              flash[:error].should_not eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              response.should_not redirect_to checkout_state_path(order.state)
            end
          end

          context 'when there are also other payment than wallet_payment' do
            it 'should not have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}, {:payment_method_id => wallet_payment_method.id}]})
              flash[:error].should_not eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}, {:payment_method_id => wallet_payment_method.id}]})
              response.should_not redirect_to checkout_state_path(order.state)
            end
          end

          context 'when remainin total is less than user\'s store_credits_total' do
            before(:each) do
              user.stub(:store_credits_total).and_return(order.remaining_total + 200)
            end

            it 'should not have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              flash[:error].should_not eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should not redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              response.should_not redirect_to checkout_state_path(order.state)
            end
          end

          context 'when there is only one wallet payment with remaining total less than store_credits_total' do
            before(:each) do
              user.stub(:store_credits_total).and_return(order.remaining_total - 200)
            end

            it 'should have flash error with message Spree.t(:not_sufficient_amount_in_wallet)' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              flash[:error].should eq(Spree.t(:not_sufficient_amount_in_wallet))
            end

            it 'should redirect to checkout_state_path' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => wallet_payment_method.id}]})
              response.should redirect_to checkout_state_path(order.state)
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

      before(:each) do
        controller.stub(:validate_payments).and_return(true)
      end

      it 'should receive has_checkout_step? with "payment" and return true' do
        order.should_receive(:has_checkout_step?).with("payment").and_return(true)
        send_request(:order => {})
      end

      it 'should receive payment? on order and return true' do
        order.should_receive(:payment?).and_return(true)
        send_request(:order => {})
      end

      context 'when payment_source is present' do
        context 'when there are source_params' do
          it 'should assign it to first in payment_attributes' do
            send_request(:payment_source => { wallet_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            controller.send(:params)[:order][:payments_attributes].first[:source_attributes].should eq(source_params)
          end
        end

        context 'when there are no source_params' do
          it 'should not assign it to first in payment_attributes' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            controller.send(:params)[:order][:payments_attributes].first[:source_attributes].should_not eq(source_params)
          end

          it 'should have original value' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            controller.send(:params)[:order][:payments_attributes].first[:source_attributes].should eq(another_source_params)
          end
        end
      end

      context 'when payment_source is not present' do
        context 'when there are source_params' do
          it 'should assign it to first in payment_attributes' do
            send_request(:payment_source => { wallet_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            controller.send(:params)[:order][:payments_attributes].first[:source_attributes].should eq(source_params)
          end
        end

        context 'when there are no source_params' do
          it 'should not assign it to first in payment_attributes' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            controller.send(:params)[:order][:payments_attributes].first[:source_attributes].should_not eq(source_params)
          end

          it 'should have its original value' do
            send_request(:payment_source => { check_payment_method.id.to_s => source_params}, :order => { :payments_attributes => [:payment_method_id => wallet_payment_method.id.to_s, :source_attributes => another_source_params]})
            controller.send(:params)[:order][:payments_attributes].first[:source_attributes].should eq(another_source_params)
          end
        end

        describe 'payment' do
          context 'when spree_current_user and order has available_wallet_payment_method' do
            before(:each) do
              controller.stub(:spree_current_user).and_return(user)
            end

            it 'should_receive spree_current_user and return user' do
              controller.should_receive(:spree_current_user).and_return(user)
              send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
            end

            context 'only wallet_payment' do
              it 'should receive wallet_payment_attributes with params[:order][:payments_attributes] containing only payment_method_id' do
                controller.should_receive(:wallet_payment_attributes).exactly(2).with([ {"payment_method_id" => "#{wallet_payment_method.id}" }]).and_return([ {"payment_method_id" => "#{wallet_payment_method.id}" }])
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
              end

              context 'when order total is min' do
                before(:each) do
                  order.stub(:remaining_total).and_return(300)
                end

                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
                  controller.send(:params)[:order][:payments_attributes].first[:payment_method_id].should eq(wallet_payment_method.id.to_s)
                  controller.send(:params)[:order][:payments_attributes].first[:amount].should eq(order.remaining_total)
                end
              end

              context 'when user store_credits_total is min' do
                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }]})
                  controller.send(:params)[:order][:payments_attributes].first[:payment_method_id].should eq(wallet_payment_method.id.to_s)    
                  controller.send(:params)[:order][:payments_attributes].first[:amount].should eq(user.store_credits_total)
                end
              end
            end

            context 'only wallet_payment and other payment' do
              it 'should receive wallet_payment_attributes with params[:order][:payments_attributes]' do
                controller.should_receive(:wallet_payment_attributes).exactly(2).with([ {"payment_method_id" => "#{wallet_payment_method.id}" }, {"payment_method_id" => "#{check_payment_method.id}" }]).and_return([ {"payment_method_id" => "#{wallet_payment_method.id}" }])
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
              end

              it 'should receive remaining_order_total_after_wallet' do
                controller.should_receive(:remaining_order_total_after_wallet).exactly(2).with(order, [{ "payment_method_id" => "#{wallet_payment_method.id}", "amount" => user.store_credits_total }]).and_return(order.remaining_total - user.store_credits_total)
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
              end

              it 'should receive non_wallet_payment_attributes' do
                controller.should_receive(:non_wallet_payment_attributes).exactly(2).with([ {"payment_method_id" => "#{wallet_payment_method.id}", "amount" => user.store_credits_total }, { "payment_method_id" => "#{check_payment_method.id}" }]).and_return([{ :payment_method_id => check_payment_method.id }])
                send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
              end

              context 'when order total is min' do
                before(:each) do
                  order.stub(:remaining_total).and_return(300)
                end

                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
                  controller.send(:params)[:order][:payments_attributes].first[:payment_method_id].should eq(wallet_payment_method.id.to_s)
                  controller.send(:params)[:order][:payments_attributes].first[:amount].should eq(order.remaining_total)
                end

                it 'should delete other payment from payments_attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, { :payment_method_id => check_payment_method.id }]})
                  controller.send(:params)[:order][:payments_attributes].should eq([{"payment_method_id" => "#{wallet_payment_method.id}", "amount" => order.remaining_total }])
                end
              end

              context 'when user store_credits_total is min' do
                it 'should set amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, {:payment_method_id => check_payment_method.id}]})
                  controller.send(:params)[:order][:payments_attributes].first[:amount].should eq(user.store_credits_total)
                end

                it 'should not delete other payment' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, {:payment_method_id => check_payment_method.id}]})
                  controller.send(:params)[:order][:payments_attributes].second[:payment_method_id].should eq(check_payment_method.id.to_s)
                end

                it 'should set remaining amount in wallet payment attributes' do
                  send_request(:order => { :payments_attributes => [ {:payment_method_id => wallet_payment_method.id }, {:payment_method_id => check_payment_method.id}]})
                  controller.send(:params)[:order][:payments_attributes].second[:amount].should eq(order.remaining_total - user.store_credits_total)
                end
              end
            end

            context 'no wallet_payment' do
              it 'should set amount in wallet payment attributes' do
                send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
                controller.send(:params)[:order][:payments_attributes].first[:payment_method_id].should eq(check_payment_method.id.to_s)
                controller.send(:params)[:order][:payments_attributes].first[:amount].should eq(order.remaining_total)
              end
            end
          end

          shared_examples_for 'not_make_wallet_payment' do
            it 'should receive spree_current_user and return nil' do
              controller.should_receive(:spree_current_user).and_return(nil)
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
            end

            it 'should receive remaining_total on order' do
              order.should_receive(:remaining_total).and_return(1000)
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
            end

            it 'should set payment_attributes first with amount' do
              send_request(:order => { :payments_attributes => [{:payment_method_id => check_payment_method.id}]})
              controller.send(:params)[:order][:payments_attributes].first[:payment_method_id].should eq(check_payment_method.id.to_s)
              controller.send(:params)[:order][:payments_attributes].first[:amount].should eq(order.remaining_total)
            end
          end

          context 'when no spree_current_user' do
            before(:each) do
              controller.stub(:check_registration).and_return(true)
              controller.stub(:spree_current_user).and_return(nil)
              order.stub(:remaining_total).and_return(1000)
            end

            it_should_behave_like 'not_make_wallet_payment'
          end

          context 'when no available_wallet_payment_method' do
            before(:each) do
              controller.stub(:check_registration).and_return(true)
              order.stub(:remaining_total).and_return(1000)
              order.stub(:available_wallet_payment_method).and_return(wallet_payment_method)
            end

            it_should_behave_like 'not_make_wallet_payment'
          end
        end
      end
    end
  end
end