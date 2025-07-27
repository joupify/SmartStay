Rails.application.routes.draw do
  
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  root 'lodgings#index'
  resources :lodgings
  get "/recommend", to: "recommendations#index"
  delete "/lodgings/:id", to: "lodgings#destroy", as: :delete_lodging
patch "/lodgings/:id", to: "lodgings#update", as: :update_lodging
  

end