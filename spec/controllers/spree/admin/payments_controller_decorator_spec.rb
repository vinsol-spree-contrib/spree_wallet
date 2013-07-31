describe Spree::Admin::PaymentsController do
  let(:user) { mock_model(Spree::User) }
  let(:order) { mock_model(Spree::Order) }
  let(:payment) { mock_model(Spree::Payment) }
  let(:payments) { [payment] }
  let(:payment_method) { mock_model(Spree::PaymentMethod) }
  let(:credit_card) { mock_model(Spree::CreditCard) }

  before(:each) do
    default_url_options[:host] = 'test.host'
    Spree::Order.stub(:find_by_number!).and_return(order)
  end

  describe '#create' do
    before(:each) do
      order.stub(:payments).and_return(payments)
      payments.stub(:build).and_return(payment)
      controller.stub(:object_params).and_return('object_params')
      controller.stub(:can_transition_to_payment).and_return(true)
      controller.stub(:load_data).and_return(true)
      controller.stub(:load_payment).and_return(true)
      controller.stub(:spree_current_user).and_return(user)
      user.stub(:generate_spree_api_key!).and_return(true)
      user.stub(:last_incomplete_spree_order).and_return(nil)
      controller.stub(:authorize!).and_return(true)
      controller.stub(:authorize_admin).and_return(true)
      payment.stub(:payment_method).and_return(payment_method)
      payment_method.stub(:is_a?).with(Spree::Gateway).and_return(true)
      payment_method.stub(:payment_profiles_supported?).and_return(true)
      payment.stub(:save).and_return(true)
      order.stub(:completed?).and_return(true)
      payment.stub(:process!).and_return(true)
      controller.stub(:flash_message_for).with(payment, :successfully_created).and_return('successfully_created')
    end

    def send_request(params = {})
      post :create, params.merge!(:id => payment.id, :order_id => order.id, :use_route => 'spree') 
    end

    it 'should receive payments and return payments' do
      order.should_receive(:payments).and_return(payments)
      send_request
    end

    it 'should receive build with object_params' do
      payments.should_receive(:build).with('object_params').and_return(payment)
      send_request
    end

    it 'should_receive object_params and return object_params' do
      controller.should_receive(:object_params).and_return('object_params')
      send_request
    end

    it 'should receive payment_method and return payment_method' do
      payment.should_receive(:payment_method).and_return(payment_method)
      send_request
    end

    it 'should receive payment_profiles_supported? and return true' do
      payment_method.should_receive(:payment_profiles_supported?).and_return(true)
      send_request
    end

    context 'when payment is Spree::Gateway, payment_profiles_supported, params card present, and is not equal to new' do
      before(:each) do
        payment_method.stub(:is_a?).with(Spree::Gateway).and_return(true)
        payment.stub(:source=).and_return(credit_card)
      end

      it 'should receive find_by_id with card' do
        Spree::CreditCard.should_receive(:find_by_id).with('card').and_return(credit_card)
        send_request(:card => 'card')
      end

      it 'should receive source= and return credit_card' do
        payment.should_receive(:source=).and_return(credit_card)
        send_request(:card => 'card')
      end
    end

    context 'when payment_method is not Spree::Gateway' do
      before(:each) do
        payment_method.stub(:is_a?).with(Spree::Gateway).and_return(false)
      end

      it 'should not receive find_by_id with card' do
        Spree::CreditCard.should_not_receive(:find_by_id)
        send_request(:card => 'card')
      end

      it 'should not receive payment_profiles_supported?' do
        payment_method.should_not_receive(:payment_profiles_supported?)
        send_request(:card => 'card')
      end

      it 'should not receive source=' do
        payment.should_not_receive(:source=)
        send_request(:card => 'card')
      end
    end

    context 'when payment_method is not payment_profiles_supported' do
      before(:each) do
        payment_method.stub(:payment_profiles_supported?).and_return(false)
      end

      it 'should not receive find_by_id with card' do
        Spree::CreditCard.should_not_receive(:find_by_id)
        send_request(:card => 'card')
      end

      it 'should not receive source=' do
        payment.should_not_receive(:source=)
        send_request(:card => 'card')
      end
    end

    context 'no params card' do
      it 'should not receive find_by_id with card' do
        Spree::CreditCard.should_not_receive(:find_by_id)
        send_request
      end

      it 'should not receive source=' do
        payment.should_not_receive(:source=)
        send_request
      end
    end

    context 'no params card' do
      it 'should not receive find_by_id with card' do
        Spree::CreditCard.should_not_receive(:find_by_id)
        send_request(:card => 'new')
      end

      it 'should not receive source=' do
        payment.should_not_receive(:source=)
        send_request(:card => 'new')
      end
    end

    context 'when payment is not able to save' do
      before(:each) do
        payment.stub(:save).and_return(false)
      end

      it 'should be success' do
        send_request
        response.should be_success
      end

      it 'should render new' do
        send_request
        response.should render_template 'payments/new'
      end

      it 'should receive save and return false' do
        payment.should_receive(:save).and_return(false)
        send_request
      end

      it 'should not receive completed? on order' do
        order.should_not_receive(:completed?)
        send_request
      end
    end

    context 'when payment is able to save' do
      before(:each) do
        payment.stub(:save).and_return(true)
      end

      it 'should not be success' do
        send_request
        response.should_not be_success
      end

      it 'should not render new' do
        send_request
        response.should_not render_template 'payments/new'
      end

      it 'should receive save and return true' do
        payment.should_receive(:save).and_return(true)
        send_request
      end

      it 'should receive completed? on order and retun true' do
        order.should_receive(:completed?).and_return(true)
        send_request
      end
    end

    context 'order completed?' do
      before(:each) do
        order.stub(:completed?).and_return(true)
        payment.stub(:process!).and_return(true)
        controller.stub(:flash_message_for).with(order, :successfully_created).and_return('successfully_created')
      end

      it 'should receive completed? and return true' do
        order.should_receive(:completed?).and_return(true)
        send_request
      end

      it 'should receive process! on payment and return true' do
        payment.should_receive(:process!).and_return(true)
        send_request
      end

      it 'should receive flash_message_for with payment, :successfully_created' do
        controller.should_receive(:flash_message_for).with(payment, :successfully_created).and_return('successfully_created')
        send_request
      end

      it 'should have success flash message' do
        send_request
        flash[:success].should eq('successfully_created')
      end

      it 'should redirect to admin_order_payments_path' do
        send_request
        response.should redirect_to admin_order_payments_path(order)
      end
    end

    context 'order not completed?' do
      before(:each) do
        order.stub(:completed?).and_return(false, false, true)
        order.stub(:next!).and_return(true)
      end

      it 'should receive completed? and return false' do
        order.should_receive(:completed?).and_return(false)
        send_request
      end

      context 'when it iterates one time' do
        it 'should receive next! on order and return true' do
          order.should_receive(:next!).and_return(true)
          send_request
        end
      end

      context 'when it iterates two times' do
        before(:each) do
          order.stub(:completed?).and_return(false, false, false, true)
        end

        it 'should receive next! on order and return true' do
          order.should_receive(:next!).exactly(2).times.and_return(true)
          send_request
        end
      end

      it 'should have success flash message' do
        send_request
        flash[:success].should eq(Spree.t(:new_order_completed))
      end

      it 'should redirect to admin_order_payments_path' do
        send_request
        response.should redirect_to edit_admin_order_url(order)
      end
    end

    context 'when it raise exception Spree::Core::GatewayError' do
      before(:each) do
        payment.stub(:save).and_raise(Spree::Core::GatewayError.new('exception_message'))
      end

      it 'should receive save and raise exception' do
        payment.should_receive(:save).and_raise(Spree::Core::GatewayError.new('exception_message'))
        send_request
      end

      it 'should have flash error with exception meassge' do
        send_request
        flash[:error].should eq('exception_message')
      end

      it 'should redirect_to new_admin_order_payment_path' do
        send_request
        response.should redirect_to new_admin_order_payment_path(order)
      end
    end
  end
end