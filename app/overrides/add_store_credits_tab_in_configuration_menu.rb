Deface::Override.new(
  :virtual_path => 'spree/admin/shared/_configuration_menu',
  :name => 'add_store_credits_to_admin_configuration_sidebar',
  :insert_bottom => "[data-hook='admin_configurations_sidebar_menu']",
  :text => %q{
    <%= configurations_sidebar_menu_item Spree.t(:store_credits), admin_store_credits_path %>
    }
)