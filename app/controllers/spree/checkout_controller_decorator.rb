Spree::CheckoutController.class_eval do
  before_filter :validate_payments, :only => :update, :if => lambda { @order && @order.has_checkout_step?("payment") && @order.payment? && @order.available_wallet_payment_method }

  private
    def object_params
      if @order.has_checkout_step?("payment") && @order.payment?
        if params[:payment_source].present?
          source_params = params.delete(:payment_source)[non_wallet_payment_method]

          if source_params
            non_wallet_payment_attributes(params[:order][:payments_attributes]).first[:source_attributes] = source_params
          end
        end

        if (params[:order][:payments_attributes])
          # This method is overrided because spree add all order total in first payment, now after wallet we can have multiple payments.
          if spree_current_user && @order.available_wallet_payment_method
            wallet_payments = wallet_payment_attributes(params[:order][:payments_attributes])
            wallet_payments.first[:amount] = [@order.remaining_total, spree_current_user.store_credits_total].min if wallet_payments.present?
            params[:order][:payments_attributes] = wallet_payments if remaining_order_total_after_wallet(@order, wallet_payments) <= 0
            non_wallet_payment_attributes(params[:order][:payments_attributes]).first[:amount] = remaining_order_total_after_wallet(@order, wallet_payments) if non_wallet_payment_attributes(params[:order][:payments_attributes]).present?
          else
            params[:order][:payments_attributes].first[:amount] = @order.remaining_total
          end
        end
      end
      params[:order]
    end

    def validate_payments
      payments_attributes = params[:order][:payments_attributes]
      wallet_payment = wallet_payment_attributes(payments_attributes)
      if !spree_current_user && wallet_payment.present?
        flash[:error] = Spree.t(:cannot_select_wallet_while_guest_checkout)
        redirect_to checkout_state_path(@order.state)
      elsif wallet_payment.present? && non_wallet_payment_attributes(payments_attributes).empty? && @order.remaining_total >= spree_current_user.store_credits_total
        flash[:error] = Spree.t(:not_sufficient_amount_in_wallet)
        redirect_to checkout_state_path(@order.state)
      end
    end

    def non_wallet_payment_method
      non_wallet_payment_attributes(params[:order][:payments_attributes]).first[:payment_method_id] if non_wallet_payment_attributes(params[:order][:payments_attributes]).first
    end

    def remaining_order_total_after_wallet(order, wallet_payments)
      wallet_payments.present? ? order.remaining_total - wallet_payments.first[:amount] : order.remaining_total
    end

    def wallet_payment_attributes(payment_attributes)
      payment_attributes.select { |payment| payment["payment_method_id"] == Spree::PaymentMethod::Wallet.first.id.to_s }
    end

    def non_wallet_payment_attributes(payment_attributes)
      @non_wallet_payment ||= payment_attributes - wallet_payment_attributes(payment_attributes)
    end
end