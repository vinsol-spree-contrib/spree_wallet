describe Spree.user_class do
  it { should have_many(:store_credits).dependent(:destroy).class_name('Spree::StoreCredit') }

  describe 'lock version' do
    context 'when an instance have not updated lock_version' do
      before(:each) do
        @user1 = Spree::User.create!(:email => 'abc@test.com', :password => '123456')
        @user2 = Spree::User.where(:email => @user1.email).first

        @user1.store_credits_total = 1000
        @user1.save!

        @user2.store_credits_total = 500
      end

      it { expect { @user2.save }.to raise_error(ActiveRecord::StaleObjectError) }
    end

    context 'when an instance have not updated lock_version' do
      before(:each) do
        @user1 = Spree::User.create!(:email => 'abc@test.com', :password => '123456')

        @user1.store_credits_total = 1000
        @user1.save!

        @user2 = Spree::User.where(:email => @user1.email).first
        @user2.store_credits_total = 500
      end

      it { expect { @user2.save }.not_to raise_error }
    end
  end
end