require 'spec_helper'

describe Spree::Admin::PaymentsController do
  let(:user) { mock_model(Spree::User) }
  let(:order) { mock_model(Spree::Order) }
  let(:payment) { mock_model(Spree::Payment) }
  let(:payments) { [payment] }
  let(:payment_method) { mock_model(Spree::PaymentMethod) }
  let(:credit_card) { mock_model(Spree::CreditCard) }

  before(:each) do
    allow(Spree::Order).to receive(:find_by_number!).and_return(order)
  end

  describe '#create' do
    before(:each) do
      allow(order).to receive(:payments).and_return(payments)
      allow(payments).to receive(:build).and_return(payment)
      allow(controller).to receive(:object_params).and_return('object_params')
      allow(controller).to receive(:can_transition_to_payment).and_return(true)
      allow(controller).to receive(:load_data).and_return(true)
      allow(controller).to receive(:load_payment).and_return(true)
      allow(controller).to receive(:spree_current_user).and_return(user)
      allow(user).to receive(:generate_spree_api_key!).and_return(true)
      allow(user).to receive(:last_incomplete_spree_order).and_return(nil)
      allow(controller).to receive(:authorize!).and_return(true)
      allow(controller).to receive(:authorize_admin).and_return(true)
      allow(payment).to receive(:payment_method).and_return(payment_method)
      allow(payment_method).to receive(:is_a?).with(Spree::Gateway).and_return(true)
      allow(payment_method).to receive(:payment_profiles_supported?).and_return(true)
      allow(payment).to receive(:save).and_return(true)
      allow(order).to receive(:completed?).and_return(true)
      allow(payment).to receive(:process!).and_return(true)
      allow(controller).to receive(:flash_message_for).with(payment, :successfully_created).and_return('successfully_created')
      allow(Spree::Order).to receive_message_chain('friendly.find').with(order.id.to_s).and_return(order)
      allow(order).to receive_message_chain('billing_address.present?').and_return(true)
      allow(order).to receive(:next).and_return(false)
      allow(payment).to receive(:checkout?).and_return(true)
      allow(payment_method).to receive(:source_required?).and_return(true)
      allow(payment_method).to receive(:payment_source_class).and_return(Spree::CreditCard)
      allow(payment).to receive(:source=).and_return(Spree::CreditCard.first)
    end

    def send_request(params = {})
      post :create, params.merge!(:id => payment.id, :order_id => order.id, :use_route => 'spree') 
    end

    it 'should receive payments and return payments' do
      expect(order).to receive(:payments).and_return(payments)
      send_request
    end

    it 'should receive build with object_params' do
      expect(payments).to receive(:build).with('object_params').and_return(payment)
      send_request
    end

    it 'should_receive object_params and return object_params' do
      expect(controller).to receive(:object_params).and_return('object_params')
      send_request
    end

    it 'should receive payment_method and return payment_method' do
      expect(payment).to receive(:payment_method).and_return(payment_method)
      send_request
    end

    context 'when payment is Spree::Gateway, payment_profiles_supported, params card present, and is not equal to new' do
      before(:each) do
        allow(payment_method).to receive(:is_a?).with(Spree::Gateway).and_return(true)
        allow(payment).to receive(:source=).and_return(credit_card)
      end

      it 'should receive find_by_id with card' do
        expect(Spree::CreditCard).to receive(:find_by_id).with('card').and_return(credit_card)
        send_request(:card => 'card')
      end

      it 'should receive source= and return credit_card' do
        expect(payment).to receive(:source=).and_return(credit_card)
        send_request(:card => 'card')
      end
    end

    context 'when payment_method is not Spree::Gateway' do
      before(:each) do
        allow(payment_method).to receive(:is_a?).with(Spree::Gateway).and_return(false)
      end

      it 'should not receive find_by_id with card' do
        expect(Spree::CreditCard).to receive(:find_by_id)
        send_request(:card => 'card')
      end

      it 'should not receive source=' do
        expect(payment).to receive(:source=)
        send_request(:card => 'card')
      end
    end

    context 'when payment_method is not payment_profiles_supported' do
      before(:each) do
        allow(payment_method).to receive(:payment_profiles_supported?).and_return(false)
      end

      it 'should not receive find_by_id with card' do
        expect(Spree::CreditCard).to receive(:find_by_id)
        send_request(:card => 'card')
      end

      it 'should not receive source=' do
        expect(payment).to receive(:source=)
        send_request(:card => 'card')
      end
    end

    context 'no params card' do
      it 'should not receive find_by_id with card' do
        expect(Spree::CreditCard).not_to receive(:find_by_id)
        send_request
      end

      it 'should not receive source=' do
        expect(payment).not_to receive(:source=)
        send_request
      end
    end

    context 'no params card' do
      it 'should not receive find_by_id with card' do
        expect(Spree::CreditCard).not_to receive(:find_by_id)
        send_request(:card => 'new')
      end

      it 'should not receive source=' do
        expect(payment).not_to receive(:source=)
        send_request(:card => 'new')
      end
    end

    context 'when payment is not able to save' do
      before(:each) do
        allow(payment).to receive(:save).and_return(false)
      end

      it 'should be success' do
        send_request
        expect(response).to be_success
      end

      it 'should render new' do
        send_request
        expect(response).to render_template 'payments/new'
      end

      it 'should receive save and return false' do
        expect(payment).to receive(:save).and_return(false)
        send_request
      end

      it 'should not receive completed? on order' do
        expect(order).not_to receive(:completed?)
        send_request
      end
    end

    context 'when payment is able to save' do
      before(:each) do
        allow(payment).to receive(:save).and_return(true)
      end

      it 'should not be success' do
        send_request
        expect(response).not_to be_success
      end

      it 'should not render new' do
        send_request
        expect(response).not_to render_template 'payments/new'
      end

      it 'should receive save and return true' do
        expect(payment).to receive(:save).and_return(true)
        send_request
      end

      it 'should receive completed? on order and retun true' do
        expect(order).to receive(:completed?).and_return(true)
        send_request
      end
    end

    context 'order completed?' do
      before(:each) do
        allow(order).to receive(:completed?).and_return(true)
        allow(payment).to receive(:process!).and_return(true)
        allow(controller).to receive(:flash_message_for).with(order, :successfully_created).and_return('successfully_created')
      end

      it 'should receive completed? and return true' do
        expect(order).to receive(:completed?).and_return(true)
        send_request
      end

      it 'should receive process! on payment and return true' do
        expect(payment).to receive(:process!).and_return(true)
        send_request
      end

      it 'should receive flash_message_for with payment, :successfully_created' do
        expect(controller).to receive(:flash_message_for).with(payment, :successfully_created).and_return('successfully_created')
        send_request
      end

      it 'should have success flash message' do
        send_request
        expect(flash[:success]).to eq('successfully_created')
      end

      it 'should redirect to admin_order_payments_path' do
        send_request
        expect(response).to redirect_to admin_order_payments_path(order)
      end
    end

    context 'order not completed?' do
      before(:each) do
        allow(order).to receive(:completed?).and_return(false, false, true)
        allow(order).to receive(:next!).and_return(true)
      end

      it 'should receive completed? and return false' do
        expect(order).to receive(:completed?).and_return(true)
        send_request
      end

      context 'when it iterates two times' do
        before(:each) do
          allow(order).to receive(:completed?).and_return(false, false, false, true)
        end
      end

      it 'should have success flash message' do
        send_request
        expect(flash[:success]).to eq('successfully_created')
      end

      it 'should redirect to admin_order_payments_path' do
        send_request
        expect(response).to redirect_to admin_order_payments_url(order, :host => 'test.host')
      end
    end

    context 'when it raise exception Spree::Core::GatewayError' do
      before(:each) do
        allow(payment).to receive(:save).and_raise(Spree::Core::GatewayError.new('exception_message'))
      end

      it 'should receive save and raise exception' do
        expect(payment).to receive(:save).and_raise(Spree::Core::GatewayError.new('exception_message'))
        send_request
      end

      it 'should have flash error with exception meassge' do
        send_request
        expect(flash[:error]).to eq('exception_message')
      end

      it 'should redirect_to new_admin_order_payment_path' do
        send_request
        expect(response).to redirect_to new_admin_order_payment_path(order)
      end
    end
  end
end
