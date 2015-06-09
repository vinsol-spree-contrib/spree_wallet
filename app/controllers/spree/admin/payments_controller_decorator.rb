Spree::Admin::PaymentsController.class_eval do
  def create
    @payment = @order.payments.build(object_params)
    if @payment.payment_method.is_a?(Spree::Gateway) && @payment.payment_method.payment_profiles_supported? && params[:card].present? and params[:card] != 'new'
      @payment.source = Spree::CreditCard.find_by_id(params[:card])
    end

    begin
      unless @payment.save
        # In spree, if payment is not able to save. It will redirect to index page, rather than it should render new with errors.
        render :new
        return
      end

      if @order.completed?
        @payment.process!
        flash[:success] = flash_message_for(@payment, :successfully_created)

         redirect_to admin_order_payments_path(@order)
      else
        #This is the first payment (admin created order)
        until @order.completed?
          @order.next!
        end
        flash[:success] = Spree.t(:new_order_completed)
        redirect_to edit_admin_order_url(@order)
      end

    rescue Spree::Core::GatewayError => e
      flash[:error] = "#{e.message}"
      redirect_to new_admin_order_payment_path(@order)
    end
  end
end