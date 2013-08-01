module Spree
  module Admin
    class StoreCreditsController < ResourceController
      helper_method :store_credit_class
      skip_before_filter :load_resource, :only => [:index]
      before_filter :disable_negative_payment_mode, :add_transactioner_to_store_credit, :only => :create

      def index
        @search = association_or_class.ransack(params[:q])
        @store_credits = @search.result.page(params[:page])
      end

      protected

        def disable_negative_payment_mode
          @store_credit.disable_negative_payment_mode = true
        end

        def add_transactioner_to_store_credit
          @store_credit.transactioner = spree_current_user
        end

        def self.parent_data
          { :model_class => Spree.user_class, :find_by => :id, :model_name => 'spree/user' }
        end

        def association_or_class
          parent ? parent.store_credits.includes(:transactioner) : Spree::StoreCredit.includes(:user, :transactioner)
        end

        def build_resource
          if parent_data.present?
            store_credit_class.new{ |store_credit| store_credit.user = parent }
          else
            store_credit_class.new
          end
        end

        def find_resource
          if parent_data.present?
            store_credit_class.where(:id => params[:id], :user_id => parent.id).first
          else
            store_credit_class.where(:id => params[:id]).first
          end
        end

        def store_credit_class
          params[:type] ? "spree/#{params[:type]}".classify.constantize : model_class
        end
    end
  end
end