module Spree
  class Debit < StoreCredit
    # Negative Payment Mode cannot be set manually. They are reserved for some particular task internally.
    PAYMENT_MODE = { 'Order Purchase' => -1, 'Deduce' => 0 }
    
    include Spree::DisableNegativePaymentModeAndSetBalanceAbility

    private
      def effective_amount(amount = amount)
        -(amount)
      end
  end
end