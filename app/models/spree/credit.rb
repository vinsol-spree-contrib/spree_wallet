module Spree
  class Credit < StoreCredit
    # Negative Payment Mode cannot be set manually. They are reserved for some particular task internally.
    PAYMENT_MODE = { 'Payment Refund' => -1, 'Refund' => 0, 'Bank' => 1 }

    include Spree::DisableNegativePaymentModeAndSetBalanceAbility

    private
      def effective_amount(credit_amount = amount)
        credit_amount.to_f
      end
  end
end
