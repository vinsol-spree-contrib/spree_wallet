Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :users, only: :none do
      resources :store_credits, only: [:index]
      resources :credits, only: [:new, :create, :show], controller: :store_credits, type: 'credits'
      resources :debits, only: [:new, :create, :show], controller: :store_credits, type: 'debits'
    end

    resources :store_credits, only: [:index]
  end
end
