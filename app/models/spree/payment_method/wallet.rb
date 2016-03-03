module Spree
  class PaymentMethod::Wallet < PaymentMethod

    def actions
      %w{void credit}
    end

    def can_credit?(payment)
      payment.completed? && payment.can_credit?
    end

    def credit(credit_cents, transaction_id, options={})
      payment = options[:originator].payment
      amount = credit_cents / 100.0
      payment.send(:credit_store_credits, amount)
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end

    def can_void?(payment)
      !['void', 'invalid'].include?(payment.state)
    end

    def void(*args)
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end

    def source_required?
      false
    end

    def cancel(*args)
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end
  end
end
