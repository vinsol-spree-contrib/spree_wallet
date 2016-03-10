require 'spec_helper'

describe Spree::Admin::StoreCreditsController do
  let(:user) { mock_model(Spree::User) }
  let(:store_credit) { mock_model(Spree::StoreCredit) }
  let(:store_credits) { [store_credit] }
  let(:ransack_search) { double(Ransack::Search) }

  before(:each) do
    allow(controller).to receive(:spree_current_user).and_return(user)
    allow(user).to receive(:authenticate)
    allow(user).to receive(:generate_spree_api_key!).and_return(true)
  end

  describe '#create' do
    let(:store_credit) { Spree::StoreCredit.new }

    def send_request(type = nil)
      post :create, { :store_credit => { :amount => 1000 }, :user_id => user.id, :type => type, :use_route => 'spree' }
    end

    before(:each) do
      allow(controller).to receive(:load_resource_instance).and_return(store_credit)
      allow(controller).to receive(:authorize_admin).and_return(true)
      allow(controller).to receive(:authorize!).and_return(true)
    end

    describe 'disable_negative_payment_mode' do
      it 'should have disable_negative_payment_mode be true' do
        send_request
        expect(store_credit.disable_negative_payment_mode).to be_truthy
      end

      it 'should receive disable_negative_payment_mode' do
        expect(controller).to receive(:disable_negative_payment_mode).and_return(true)
        send_request
      end
    end

    describe 'add_transactioner_to_store_credit' do
      it 'should have transactioner be user' do
        send_request
        expect(store_credit.transactioner).to eq(user)
      end

      it 'should receive add_transactioner_to_store_credit' do
        expect(controller).to receive(:add_transactioner_to_store_credit).and_return(true)
        send_request
      end
    end
  end

  describe '#index' do
    before(:each) do
      allow(controller).to receive(:parent).and_return(user)
      allow(user).to receive(:store_credits).and_return(store_credits)
      allow(store_credits).to receive(:order_created_at_desc).and_return(store_credits)
      allow(store_credits).to receive(:ransack).and_return(ransack_search)
      allow(controller).to receive(:authorize_admin).and_return(true)
      allow(ransack_search).to receive(:result).and_return(store_credits)
      allow(store_credits).to receive(:page).and_return(store_credits)
      allow(store_credits).to receive(:includes).and_return(store_credits)
    end

    def send_request(params = {})
      get :index, params.merge!(:use_route => 'spree')
    end

    it 'should receive association_or_class and return store_credits' do
      expect(controller).to receive(:association_or_class).and_return(store_credits)
      send_request
    end

    it 'should receive order_created_at_desc and return store_credits' do
      expect(store_credits).to receive(:order_created_at_desc).and_return(store_credits)
      send_request
    end

    it 'should not receive load_resource' do
      expect(controller).not_to receive(:load_resource)
      send_request
    end

    context 'when there is parent' do
      it 'should receive parent exactly three times and return user' do
        expect(controller).to receive(:parent).exactly(3).times.and_return(user)
        send_request
      end

      it 'should receive store_credits on user and return store_credits' do
        expect(user).to receive(:store_credits).and_return(store_credits)
        send_request
      end
    end

    context 'when there is no parent' do
      before(:each) do
        allow(controller).to receive(:parent).and_return(nil)
        allow(Spree::StoreCredit).to receive(:ransack).and_return(ransack_search)
      end

      it 'should receive parent and return nil' do
        expect(controller).to receive(:parent).and_return(nil)
        send_request
      end
    end

    it 'should receive ransack' do
      expect(store_credits).to receive(:ransack).with("amount_eq" => "1000").and_return(ransack_search)
      send_request(:q => { :amount_eq => 1000 })
    end

    it 'should assigns @search with ransack_search' do
      send_request(:q => { :amount_eq => 1000 })
      expect(assigns(:search)).to eq(ransack_search)
    end

    it 'should be success' do
      send_request
      expect(response).to be_success
    end

    it 'should render template spree/admin/store_credits/index' do
      send_request
      expect(response).to render_template 'spree/admin/store_credits/index'
    end

    it 'should receive result and return store_credits' do
      expect(ransack_search).to receive(:result).and_return(store_credits)
      send_request
    end

    it 'should receive page and return store_credits' do
      expect(store_credits).to receive(:page).with("1").and_return(store_credits)
      send_request(:page => 1)
    end

    context 'when there is parent' do
      it 'should receive required_includes_arguements and return :transactioner' do
        expect(controller).to receive(:required_includes_arguements).and_return(:transactioner)
        send_request(:page => 1)
      end

      it 'should receive includes :transactioner' do
        expect(store_credits).to receive(:includes).with(:transactioner).and_return(store_credits)
        send_request(:page => 1)
      end
    end

    context 'when there is no parent' do
      before(:each) do
        allow(controller).to receive(:parent).and_return(nil)
        allow(Spree::StoreCredit).to receive(:ransack).and_return(ransack_search)
      end

      it 'should receive required_includes_arguements and return :transactioner' do
        expect(controller).to receive(:required_includes_arguements).and_return([:transactioner, :user])
        send_request(:page => 1)
      end

      it 'should receive includes [:transactioner, :user]' do
        expect(store_credits).to receive(:includes).with([:transactioner, :user]).and_return(store_credits)
        send_request(:page => 1)
      end
    end

    it 'should assign @store_credits with store_credits' do
      send_request
      expect(assigns(:store_credits)).to eq(store_credits)
    end
  end

  describe 'parent_data' do
    it 'should eq { :model_class => Spree.user_class, :find_by => :id, :model_name => spree/user }' do
      expect(Spree::Admin::StoreCreditsController.send(:parent_data)).to eq({ :model_class => Spree.user_class, :find_by => :id, :model_name => 'spree/user' })
    end
  end

  describe 'new' do
    def send_request
      get :new, :user_id => user.id, :use_route => 'spree'
    end

    describe 'build_resouce' do
      before(:each) do
        allow(controller).to receive(:authorize_admin).and_return(true)
      end

      it 'should receive load_resource' do
        expect(controller).to receive(:load_resource).and_return(true)
        send_request
      end

      context 'no parent_data' do
        before(:each) do
          allow(Spree::Admin::StoreCreditsController).to receive(:parent_data).and_return({})
          allow(controller).to receive(:store_credit_class).and_return(Spree::StoreCredit)
          allow(Spree::StoreCredit).to receive(:new).and_return(store_credit)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          expect(controller).to receive(:store_credit_class).and_return(Spree::StoreCredit)
          send_request
        end

        it 'should receive new on Spree::StoreCredit and return store_credit' do
          expect(Spree::StoreCredit).to receive(:new).and_return(store_credit)
          send_request
        end
      end

      context 'parent_data' do
        before(:each) do
          allow(controller).to receive(:store_credit_class).and_return(Spree::Credit)
          allow(Spree::Credit).to receive(:new).and_return(store_credit)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          expect(controller).to receive(:store_credit_class).and_return(Spree::Credit)
          send_request
        end

        it 'should receive new on Spree::StoreCredit and return store_credit' do
          expect(Spree::Credit).to receive(:new).and_return(store_credit)
          send_request
        end
      end
    end
  end

  describe 'edit' do
    def send_request(type = nil)
      get :edit, :id => store_credit.id, :user_id => user.id, :type => type, :use_route => 'spree'
    end

    describe 'build_resouce' do
      before(:each) do
        allow(controller).to receive(:authorize_admin).and_return(true)
      end

      context 'no parent_data' do
        before(:each) do
          allow(Spree::Admin::StoreCreditsController).to receive(:parent_data).and_return({})
          allow(controller).to receive(:model_class).and_return(Spree::StoreCredit)
          allow(Spree::StoreCredit).to receive(:where).and_return(store_credits)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          expect(controller).to receive(:store_credit_class).and_return(Spree::StoreCredit)
          send_request
        end

        it 'should receive model_class and return Spree::StoreCredit' do
          expect(controller).to receive(:model_class).and_return(Spree::StoreCredit)
          send_request
        end

        it 'should receive where with :id => store_credit.id on Spree::StoreCredit and return store_credit' do
          expect(Spree::StoreCredit).to receive(:where).with(:id => store_credit.id.to_s).and_return(store_credits)
          send_request
        end
      end

      context 'parent_data' do
        before(:each) do
          allow(Spree::Credit).to receive(:where).and_return(store_credits)
          allow(controller).to receive(:parent).and_return(user)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          expect(controller).to receive(:store_credit_class).and_return(Spree::Credit)
          send_request('credits')
        end

        it 'should receive where with :id => store_credit.id, :user_id => user.id on Spree::StoreCredit and return store_credits' do
          expect(Spree::Credit).to receive(:where).with(:id => store_credit.id.to_s, :user_id => user.id).and_return(store_credits)
          send_request('credits')
        end

        it 'should_receive parent and return user' do
          allow(controller).to receive(:parent).and_return(user)
          send_request('credits')
        end
      end
    end
  end
end