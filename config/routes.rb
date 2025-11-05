Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # React dashboard routes
  get "tutor/:id", to: "tutors#show", as: :tutor_dashboard
  get "admin/:id", to: "admins#show", as: :admin_dashboard

  # API routes
  namespace :api do
    namespace :tutor do
      get ":id/fsrs_latest", to: "tutors#fsrs_latest"
      get ":id/fsrs_history", to: "tutors#fsrs_history"
      get ":id/performance_summary", to: "tutors#performance_summary"
      get ":id/session_list", to: "tutors#session_list"
    end

    namespace :admin do
      namespace :tutors do
        get "risk_list", to: "tutors#risk_list"
      end
      
      namespace :tutor do
        get ":id/metrics", to: "tutors#metrics"
        get ":id/fsrs_history", to: "tutors#fsrs_history"
        get ":id/intervention_log", to: "tutors#intervention_log"
      end

      namespace :alerts do
        post ":id/update_status", to: "alerts#update_status"
      end
    end
  end

  # Sidekiq dashboard (require authentication in production)
  require "sidekiq/web"
  mount Sidekiq::Web => "/sidekiq"

  # Defines the root path route ("/")
  # root "posts#index"
end
