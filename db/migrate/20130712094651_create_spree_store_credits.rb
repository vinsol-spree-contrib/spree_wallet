class CreateSpreeStoreCredits < ActiveRecord::Migration
  def change
    create_table :spree_store_credits do |t|
      t.string :reason
      t.string :type
      t.string :transaction_id
      t.decimal :amount, precision: 10, scale: 2
      t.decimal :balance, precision: 10, scale: 2
      t.integer :payment_mode
      t.references :user

      t.timestamps
    end
  end
end
