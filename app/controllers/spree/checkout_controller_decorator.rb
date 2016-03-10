Spree::CheckoutController.class_eval do
  before_action :validate_payments, only: :update, if: :check_wallet_payment?

  private
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

    def wallet_payment_attributes(payment_attributes)
      payment_attributes.select { |payment| payment["payment_method_id"] == Spree::PaymentMethod::Wallet.first.id.to_s }
    end

    def non_wallet_payment_attributes(payment_attributes)
      @non_wallet_payment ||= payment_attributes - wallet_payment_attributes(payment_attributes)
    end

    def check_wallet_payment?
      @order && @order.has_checkout_step?("payment") && @order.payment? &&
        @order.available_wallet_payment_method
    end
end
