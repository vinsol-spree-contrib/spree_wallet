module Spree
  class Debit < StoreCredit
    # Negative Payment Mode cannot be set manually. They are reserved for some particular task internally.
    PAYMENT_MODE = { 'Order Purchase' => -1, 'Deduce' => 0 }

    include Spree::DisableNegativePaymentModeAndSetBalanceAbility

    private
      def effective_amount(debit_amount = amount)
        -(debit_amount).to_f
      end
  end
end
