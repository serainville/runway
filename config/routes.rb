Rails.application.routes.draw do
  resources :applications, only: [:index, :create]
  resource :registration, only: [:new, :create]
  resource :session, only: [:new, :create, :destroy]
  resource :dashboard, only: [:show], controller: :dashboard
  resource :account, only: [:show]
  patch "account/password", to: "accounts#password", as: :account_password
  namespace :admin do
    resources :builds, only: [:index, :show]
    resources :users, only: [:index, :update] do
      patch :reset_password, on: :member
    end
    resources :projects, only: [:index, :update]
    resources :project_applications, only: [:index, :update]
    resources :repository_connections, only: [:index, :show, :create, :update, :destroy] do
      patch :validate_connection, on: :member
    end
    resources :backend_targets, only: [:index, :create, :update, :destroy] do
      patch :validate_connection, on: :member
    end
    resources :build_integrations, only: [:index, :show, :edit, :create, :update, :destroy] do
      collection do
        get :docker_hosts
        get :executors
      end
      patch :toggle_active, on: :member
      patch :validate_connection, on: :member
    end
  end
  resources :projects, only: [:index, :show, :new, :create] do
    resources :repository_connections, only: [:index, :show, :create, :update, :destroy], controller: :project_repository_connections do
      patch :validate_connection, on: :member
    end
    resources :applications, only: [:index, :show, :new, :create], controller: :project_applications do
      post :start_build, on: :member
      collection do
        get :discover_repositories
        post :verify_repository_access
      end
      resources :environments, only: [:show], controller: :application_environments
      resources :builds, only: [:show], controller: :project_application_builds do
        patch :cancel, on: :member
      end
    end
  end

  namespace :internal do
    post "build-executor/callbacks", to: "build_executor/callbacks#create"
    post "build-executor/heartbeats", to: "build_executor/heartbeats#create"

    namespace :builds do
      post "worker/claim", to: "workers#claim"
      post "worker/heartbeat", to: "workers#heartbeat"
      post "worker/phase", to: "workers#phase"
      post "worker/logs", to: "workers#logs"
      post "worker/complete", to: "workers#complete"
    end
  end

  get "home", to: "home#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end
