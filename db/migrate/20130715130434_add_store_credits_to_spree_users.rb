class AddStoreCreditsToSpreeUsers < ActiveRecord::Migration
  def change
    add_column :spree_users, :store_credits_total, :decimal, precision: 10, scale:  2, default:  0.0
  end
end
