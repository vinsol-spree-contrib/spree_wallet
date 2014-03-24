require 'spec_helper'

describe Spree::Admin::StoreCreditsController do
  let(:user) { mock_model(Spree::User) }
  let(:store_credit) { mock_model(Spree::StoreCredit) }
  let(:store_credits) { [store_credit] }
  let(:ransack_search) { double(Ransack::Search) }

  before(:each) do
    controller.stub(:spree_current_user).and_return(user)
    user.stub(:authenticate)
    user.stub(:generate_spree_api_key!).and_return(true)
  end

  describe '#create' do
    let(:store_credit) { Spree::StoreCredit.new }

    def send_request(type = nil)
      post :create, { :store_credit => { :amount => 1000 }, :user_id => user.id, :type => type, :use_route => 'spree' }
    end

    before(:each) do
      controller.stub(:load_resource_instance).and_return(store_credit)
      controller.stub(:authorize_admin).and_return(true)
      controller.stub(:authorize!).and_return(true)
    end

    describe 'disable_negative_payment_mode' do
      it 'should have disable_negative_payment_mode be true' do
        send_request
        store_credit.disable_negative_payment_mode.should be_true
      end

      it 'should receive disable_negative_payment_mode' do
        controller.should_receive(:disable_negative_payment_mode).and_return(true)
        send_request
      end
    end

    describe 'add_transactioner_to_store_credit' do
      it 'should have transactioner be user' do
        send_request
        store_credit.transactioner.should eq(user)
      end

      it 'should receive add_transactioner_to_store_credit' do
        controller.should_receive(:add_transactioner_to_store_credit).and_return(true)
        send_request
      end
    end
  end

  describe '#index' do
    before(:each) do
      controller.stub(:parent).and_return(user)
      user.stub(:store_credits).and_return(store_credits)
      store_credits.stub(:order_created_at_desc).and_return(store_credits)
      store_credits.stub(:ransack).and_return(ransack_search)
      controller.stub(:authorize_admin).and_return(true)
      ransack_search.stub(:result).and_return(store_credits)
      store_credits.stub(:page).and_return(store_credits)
      store_credits.stub(:includes).and_return(store_credits)
    end

    def send_request(params = {})
      get :index, params.merge!(:use_route => 'spree')
    end

    it 'should receive association_or_class and return store_credits' do
      controller.should_receive(:association_or_class).and_return(store_credits)
      send_request
    end

    it 'should receive order_created_at_desc and return store_credits' do
      store_credits.should_receive(:order_created_at_desc).and_return(store_credits)
      send_request
    end

    it 'should not receive load_resource' do
      controller.should_not_receive(:load_resource)
      send_request
    end

    context 'when there is parent' do
      it 'should receive parent exactly three times and return user' do
        controller.should_receive(:parent).exactly(3).times.and_return(user)
        send_request
      end

      it 'should receive store_credits on user and return store_credits' do
        user.should_receive(:store_credits).and_return(store_credits)
        send_request
      end
    end

    context 'when there is no parent' do
      before(:each) do
        controller.stub(:parent).and_return(nil)
        Spree::StoreCredit.stub(:ransack).and_return(ransack_search)
      end

      it 'should receive parent and return nil' do
        controller.should_receive(:parent).and_return(nil)
        send_request
      end
    end

    it 'should receive ransack' do
      store_credits.should_receive(:ransack).with("amount_eq" => "1000").and_return(ransack_search)
      send_request(:q => { :amount_eq => 1000 })
    end

    it 'should assigns @search with ransack_search' do
      send_request(:q => { :amount_eq => 1000 })
      assigns(:search).should eq(ransack_search)
    end

    it 'should be success' do
      send_request
      response.should be_success
    end

    it 'should render template spree/admin/store_credits/index' do
      send_request
      response.should render_template 'spree/admin/store_credits/index'
    end

    it 'should receive result and return store_credits' do
      ransack_search.should_receive(:result).and_return(store_credits)
      send_request
    end

    it 'should receive page and return store_credits' do
      store_credits.should_receive(:page).with("1").and_return(store_credits)
      send_request(:page => 1)
    end

    context 'when there is parent' do
      it 'should receive required_includes_arguements and return :transactioner' do
        controller.should_receive(:required_includes_arguements).and_return(:transactioner)
        send_request(:page => 1)
      end

      it 'should receive includes :transactioner' do
        store_credits.should_receive(:includes).with(:transactioner).and_return(store_credits)
        send_request(:page => 1)
      end
    end

    context 'when there is no parent' do
      before(:each) do
        controller.stub(:parent).and_return(nil)
        Spree::StoreCredit.stub(:ransack).and_return(ransack_search)
      end

      it 'should receive required_includes_arguements and return :transactioner' do
        controller.should_receive(:required_includes_arguements).and_return([:transactioner, :user])
        send_request(:page => 1)
      end

      it 'should receive includes [:transactioner, :user]' do
        store_credits.should_receive(:includes).with([:transactioner, :user]).and_return(store_credits)
        send_request(:page => 1)
      end
    end

    it 'should assign @store_credits with store_credits' do
      send_request
      assigns(:store_credits).should eq(store_credits)
    end
  end

  describe 'parent_data' do
    it 'should eq { :model_class => Spree.user_class, :find_by => :id, :model_name => spree/user }' do
      Spree::Admin::StoreCreditsController.send(:parent_data).should eq({ :model_class => Spree.user_class, :find_by => :id, :model_name => 'spree/user' })
    end
  end

  describe 'new' do
    def send_request
      get :new, :user_id => user.id, :use_route => 'spree'
    end

    describe 'build_resouce' do
      before(:each) do
        controller.stub(:authorize_admin).and_return(true)
      end

      it 'should receive load_resource' do
        controller.should_receive(:load_resource).and_return(true)
        send_request
      end

      context 'no parent_data' do
        before(:each) do
          Spree::Admin::StoreCreditsController.stub(:parent_data).and_return({})
          controller.stub(:store_credit_class).and_return(Spree::StoreCredit)
          Spree::StoreCredit.stub(:new).and_return(store_credit)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          controller.should_receive(:store_credit_class).and_return(Spree::StoreCredit)
          send_request
        end

        it 'should receive new on Spree::StoreCredit and return store_credit' do
          Spree::StoreCredit.should_receive(:new).and_return(store_credit)
          send_request
        end
      end

      context 'parent_data' do
        before(:each) do
          controller.stub(:store_credit_class).and_return(Spree::Credit)
          Spree::Credit.stub(:new).and_return(store_credit)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          controller.should_receive(:store_credit_class).and_return(Spree::Credit)
          send_request
        end

        it 'should receive new on Spree::StoreCredit and return store_credit' do
          Spree::Credit.should_receive(:new).and_return(store_credit)
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
        controller.stub(:authorize_admin).and_return(true)
      end

      context 'no parent_data' do
        before(:each) do
          Spree::Admin::StoreCreditsController.stub(:parent_data).and_return({})
          controller.stub(:model_class).and_return(Spree::StoreCredit)
          Spree::StoreCredit.stub(:where).and_return(store_credits)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          controller.should_receive(:store_credit_class).and_return(Spree::StoreCredit)
          send_request
        end

        it 'should receive model_class and return Spree::StoreCredit' do
          controller.should_receive(:model_class).and_return(Spree::StoreCredit)
          send_request
        end

        it 'should receive where with :id => store_credit.id on Spree::StoreCredit and return store_credit' do
          Spree::StoreCredit.should_receive(:where).with(:id => store_credit.id.to_s).and_return(store_credits)
          send_request
        end
      end

      context 'parent_data' do
        before(:each) do
          Spree::Credit.stub(:where).and_return(store_credits)
          controller.stub(:parent).and_return(user)
        end

        it 'should receive store_credit_class and return Spree::StoreCredit' do
          controller.should_receive(:store_credit_class).and_return(Spree::Credit)
          send_request('credits')
        end

        it 'should receive where with :id => store_credit.id, :user_id => user.id on Spree::StoreCredit and return store_credits' do
          Spree::Credit.should_receive(:where).with(:id => store_credit.id.to_s, :user_id => user.id).and_return(store_credits)
          send_request('credits')
        end

        it 'should_receive parent and return user' do
          controller.stub(:parent).and_return(user)
          send_request('credits')
        end
      end
    end
  end
end