class AddLockVersionToSpreeUsers < ActiveRecord::Migration
  def change
    add_column :spree_users, :lock_version, :integer, :default => 0
  end
end
