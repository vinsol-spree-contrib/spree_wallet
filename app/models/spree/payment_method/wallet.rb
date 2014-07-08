module Spree
  class PaymentMethod::Wallet < PaymentMethod
    def actions
      %w{void}
    end

    def can_void?(payment)
      payment.state != 'void'
    end

    def void(*args)
      ActiveMerchant::Billing::Response.new(true, "", {}, {})
    end

    def source_required?
      false
    end

    def guest_checkout?
      false
    end
  end
end
