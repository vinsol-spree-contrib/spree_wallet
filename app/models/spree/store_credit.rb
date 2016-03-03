module Spree
  class StoreCredit < ActiveRecord::Base
    attr_accessor :disable_negative_payment_mode

    belongs_to :transactioner, class_name: Spree.user_class

    validates :amount, :user_id, :reason, :type, :balance, :transaction_id, presence: true
    validates :amount, :balance, numericality: { greater_than_or_equal_to: 0 }, allow_blank: true
    validates :transaction_id, uniqueness: true, allow_blank: true

    belongs_to :user, class_name: Spree.user_class

    before_validation :generate_transaction_id, on: :create
    before_create :update_user_wallet

    scope :order_created_at_desc, -> { order('created_at desc') }

    private
      def update_user_wallet
        user.update_attribute(:store_credits_total, balance)
      end

      def generate_transaction_id
        begin
          self.transaction_id = (Time.now.strftime("%s") + rand(999999).to_s).to(15)
        end while Spree::StoreCredit.where(transaction_id: transaction_id).present?
      end
  end
end
