shared_examples_for 'disable_negative_payment_mode' do |klass|
  let(:store_credit) { klass.new }
  subject { store_credit }

  describe 'attr_accessor' do
    it 'should change the assigned value' do
      store_credit.disable_negative_payment_mode.should_not eq(true)
      store_credit.disable_negative_payment_mode = true
      store_credit.disable_negative_payment_mode.should eq(true)
    end

    it 'should create an instance_variable' do
      store_credit.disable_negative_payment_mode = true
      store_credit.instance_variable_get(:@disable_negative_payment_mode).should eq(true)
    end
  end
  
  describe 'validates' do
    describe 'inclusion_of PAYMENT_MODE' do
      context 'when negative_payment_mode is disabled' do
        before(:each) do
          store_credit.disable_negative_payment_mode = true
        end

        klass::PAYMENT_MODE.values.select { |value| value >= 0 }.each do |value|
          it { should allow_value(value).for(:payment_mode) }
        end

        klass::PAYMENT_MODE.values.select { |value| value < 0 }.each do |value|
          it { should_not allow_value(value).for(:payment_mode) }
        end

        it { should_not allow_value(klass::PAYMENT_MODE.values.last + 1).for(:payment_mode) }
      end

      context 'when negative_payment_mode is disabled' do
        before(:each) do
          store_credit.disable_negative_payment_mode = false
        end

        klass::PAYMENT_MODE.values.select { |value| value >= 0 }.each do |value|
          it { should allow_value(value).for(:payment_mode) }
        end

        klass::PAYMENT_MODE.values.select { |value| value < 0 }.each do |value|
          it { should allow_value(value).for(:payment_mode) }
        end

        it { should_not allow_value(klass::PAYMENT_MODE.values.last + 1).for(:payment_mode) }
      end
    end
  end
end