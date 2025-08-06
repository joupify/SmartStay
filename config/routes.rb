Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root "lodgings#index"
  resources :lodgings
  delete "/lodgings/:id", to: "lodgings#destroy", as: :delete_lodging
  patch "/lodgings/:id", to: "lodgings#update", as: :update_lodging
  get "/lodgings/:id/similar", to: "lodgings#similar", as: :similar_lodging
  get "/dashboard", to: "dashboard#index", as: :dashboard
end
