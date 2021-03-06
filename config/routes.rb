require 'sidekiq/web'

Partsbuilder::Application.routes.draw do

  get "jobs/show"

  get "auto_build/create"

  get "auto_builds/get_description_file"

  get "home/index"
  
  get "home/search_result"

  get "sequence/create"

  get "part/create"

  get "parts/get_description_file"
  
  get "parts/get_fasta_file"
 
  get "parts/get_csv_template"

  get "designs/fasta"

  get "sessions/guest"

  match "/orders/:id/get_zip_file", :to => "orders#get_zip_file" 
  match "/file_converts/:id/get_zip_file", :to => "file_converts#get_zip_file" 
  match "/auth/:provider/callback" => "sessions#create"
  match "/signout" => "sessions#destroy", :as => :signout
  match "/auto_builds/confirm" => "auto_builds#confirm", :via => :post
  match "/parts/confirm" => "parts#confirm", :via => :post
  match "/home/search_result" => "home#search_result", :via => :post

  resources :protocols
  resources :tutorials
  resources :constructs
  resources :orders
  resources :users
  resources :labs
  resources :designs
  resources :file_converts
  resources :parts do
    resources :designs
  end
  resources :sequences
  resources :organisms
  resources :jobs
  resources :auto_builds


  root :to => 'home#index'

  namespace :admin do
    root :to => "home#index"
    resources :protocols, :home, :users
  end

  mount Sidekiq::Web, at: '/sidekiq'
  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)'
end
