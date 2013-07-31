Spree.user_class.class_eval do
  has_many :store_credits, :class_name => 'Spree::StoreCredit', :dependent => :destroy
end