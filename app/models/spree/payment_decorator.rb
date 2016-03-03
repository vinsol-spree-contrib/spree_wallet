Spree::Payment.class_eval do
  validates :amount, numericality: {
    less_than_or_equal_to: :minimum_amount,
    greater_than_or_equal_to: 0
  }, if: :validate_wallet_amount?, allow_blank: true

  validates :amount, numericality: {
    less_than_or_equal_to: :order_total_remaining
  }, unless: :wallet?, if: :amount_changed?, allow_blank: true

  validate :restrict_wallet_when_no_user

  after_create :complete!, if: :wallet?

  delegate :remaining_total, :user_or_by_email, to: :order, prefix: true, allow_nil: true

  fsm = self.state_machines[:state]
  fsm.after_transition from: fsm.states.map(&:name) - [:completed], to: :completed, do: :consume_user_credits, if: :wallet?
  fsm.after_transition from: :completed, to: fsm.states.map(&:name) - [:completed], do: :release_user_credits, if: :wallet?

  def wallet?
    payment_method.is_a? Spree::PaymentMethod::Wallet
  end

  def invalidate_old_payments
    order.payments.with_state('checkout').where("id != ?", self.id).each do |payment|
      payment.invalidate!
    end unless wallet?
  end

  private

    def restrict_wallet_when_no_user
      if wallet? && !order_user_or_by_email
        self.errors[:base] = Spree.t(:wallet_not_linked_to_user)
      end
    end

    def consume_user_credits
      debit_store_credits(amount)
    end

    def release_user_credits
      credit_store_credits(credit_allowed)
    end

    def debit_store_credits(amount)
      Spree::Debit.create!(
        amount: amount,
        payment_mode: Spree::Debit::PAYMENT_MODE['Order Purchase'],
        reason: "Payment consumed for order #{order.number}",
        user: order_user_or_by_email, balance: calculate_balance(amount)
      )
    end

    def credit_store_credits(amount)
      Spree::Credit.create!(
        amount: amount,
        payment_mode: Spree::Credit::PAYMENT_MODE['Payment Refund'],
        reason: "Payment released for order #{order.number}",
        user: order_user_or_by_email, balance: calculate_balance(amount)
      )
    end

    def calculate_balance(amount)
      order_user_or_by_email.store_credits_total - amount
    end

    def minimum_amount
      [order_user_or_by_email.store_credits_total.to_f, order_remaining_total.to_f].min
    end

    def validate_wallet_amount?
      order_user_or_by_email && wallet? && amount_changed?
    end

    def order_total_remaining
      order_remaining_total.to_f
    end
end
