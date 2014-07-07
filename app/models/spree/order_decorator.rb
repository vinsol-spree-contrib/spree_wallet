Spree::Order.class_eval do
  fsm = self.state_machines[:state]
  fsm.after_transition :to => [:canceled], :do => :make_wallet_payments_void
  fsm.before_transition :to => :complete, :do => :complete_wallet_payment

  def user_or_by_email
    user ? user : Spree::User.where(:email => email).first
  end

  def make_wallet_payments_void
    wallet_payments.each { |p| p.void! if p.can_void? }
  end

  def has_unprocessed_payments?
    payments.with_state('checkout').reload.exists? || (available_wallet_payment_method.present? && (wallet_payment = payments.where(:payment_method_id => available_wallet_payment_method.id).last).present? && wallet_payment.amount <= remaining_total)
  end

  def remaining_total
    total - payment_total
  end

  def available_payment_methods_without_wallet
    available_payment_methods.reject { |p| p.is_a? Spree::PaymentMethod::Wallet }
  end

  def available_wallet_payment_method
    @wallet_payment_method ||= available_payment_methods.select { |p| p.is_a? Spree::PaymentMethod::Wallet }.first
  end

  def other_than_wallet_payment_required?
    remaining_total > user.store_credits_total
  end

  def available_wallet_payment_amount
    [remaining_total, user_or_by_email.store_credits_total].min
  end

  def display_available_wallet_payment_amount
    Spree::Money.new(available_wallet_payment_amount)
  end

  def remaining_total_after_wallet
    remaining_total -  available_wallet_payment_amount
  end

  def display_remaining_total_after_wallet
    Spree::Money.new(remaining_total_after_wallet)
  end

  def process_payments!    
    if pending_payments.empty? && wallet_payments.empty?
      raise Spree::Core::GatewayError.new Spree.t(:no_pending_payments)
    else
      [pending_payments, wallet_payments].flatten.each do |payment|
        break if payment_total >= total

        payment.process!

        if payment.completed?
          self.payment_total += payment.amount
        end
      end
    end
  rescue Spree::Core::GatewayError => e
    result = !!Spree::Config[:allow_checkout_on_gateway_error]
    errors.add(:base, e.message) and return result
  end


  ### This methods are extensions of spree/order/checkout.rb

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
          @updating_params[:order][:payments_attributes] = wallet_payments if remaining_order_total_after_wallet(wallet_payments) <= 0
          non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).first[:amount] = remaining_order_total_after_wallet(wallet_payments) if non_wallet_payment_attributes(@updating_params[:order][:payments_attributes]).present?
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
    payment_attributes = payment_attributes.values if payment_attributes.is_a?(Hash)
    @non_wallet_payment ||= payment_attributes - wallet_payment_attributes(payment_attributes)
  end

  private
    def wallet_payments
      payments.where(:payment_method_id => Spree::PaymentMethod::Wallet.pluck(:id))
    end

    def complete_wallet_payment
      wallet_payments.with_state('checkout').each { |payment| payment.complete! }
    end
end