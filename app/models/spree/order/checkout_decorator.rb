Spree::Order::Checkout.class_eval do
  def update_params_payment_source
    if has_checkout_step?("payment") && self.payment?
      if @updating_params[:payment_source].present?
        source_params = @updating_params.delete(:payment_source)[non_wallet_payment_method]

        if source_params
          non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).first[:source_attributes] = source_params
        end
      end

      if (@updating_params[:order][:payments_attributes])
        user = user_or_by_email
        # This method is overrided because spree add all order total in first payment, now after wallet we can have multiple payments.
        if user && available_wallet_payment_method
          wallet_payments = wallet_payment_attributes(@updating_params[:order][:payments_attributes])
          wallet_payments.first[:amount] = [remaining_total, user.store_credits_total].min if wallet_payments.present?
          @updating_params[:order][:payments_attributes] = wallet_payments if remaining_order_total_after_wallet(@order, wallet_payments) <= 0
          non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).first[:amount] = remaining_order_total_after_wallet(@order, wallet_payments) if non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).present?
        else
          @updating_params[:order][:payments_attributes].first[:amount] = remaining_total
        end
      end
    end
    @updating_params[:order]
  end

  def non_wallet_payment_method
    non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).first[:payment_method_id] if non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).first
  end

  def remaining_order_total_after_wallet(wallet_payments)
    wallet_payments.present? ? remaining_total - wallet_payments.first[:amount] : remaining_total
  end

  def wallet_payment_attributes(payment_attributes)
    payment_attributes.select { |payment| payment["payment_method_id"] == Spree::PaymentMethod::Wallet.first.id.to_s }
  end

  def non_wallet_payment_attributes(payment_attributes)
    @non_wallet_payment ||= payment_attributes - wallet_payment_attributes(payment_attributes)
  end
end