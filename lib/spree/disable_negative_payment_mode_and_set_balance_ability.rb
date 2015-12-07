module Spree
  module DisableNegativePaymentModeAndSetBalanceAbility
    def self.included(klass)
      klass.class_eval do
        attr_accessor :disable_negative_payment_mode

        validates :payment_mode, inclusion: { in: klass::PAYMENT_MODE.values }, unless: :disable_negative_payment_mode
        validates :payment_mode, inclusion: { in: klass::PAYMENT_MODE.values.select { |value| value >= 0 } }, if: :disable_negative_payment_mode

        before_validation :set_balance, on: :create
      end
    end

    def set_balance
      self.balance = user.store_credits_total + (effective_amount(amount) || 0.00) if user && amount
    end
  end
end
