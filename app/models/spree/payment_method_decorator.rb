Spree::PaymentMethod.class_eval do
  def guest_checkout?
    true
  end
end