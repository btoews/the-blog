Rails.application.routes.draw do
  root "posts#index"

  resources :posts do
    collection do
      get :search
    end

    member do
      post :like
      post :dislike
    end
  end

  resources :users, only: %w(new create) do
    collection do
      get :invites
    end
  end

  get  "/login",  to: "sessions#new",     as: :login
  post "/login",  to: "sessions#create"
  post "/logout", to: "sessions#destroy", as: :logout
end
