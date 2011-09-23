MAdeKMongo::Application.routes.draw do

  root :to => "application#root"

###############################################
  
  match '/help', :to => "application#help"
  match '/feedback', :to => "application#feedback"

  match '/login', :to => "authenticator/zhdk#login"
  match '/logout', :to => "authenticator/zhdk#logout"
  match '/db/login', :to => "authenticator/database_authentication#login"
  match '/db/logout', :to => "authenticator/database_authentication#logout"
  match '/authenticator/zhdk/login_successful/:id', :to => "authenticator/zhdk#login_successful"

###############################################

  match '/import', :to => Upload::Import
  match '/upload.js', :to => Upload::Import
  match '/upload_estimation.js', :to => Upload::Estimation
  match '/download', :to => Download
  match '/nagiosstat', :to => Nagiosstat
  
###############################################

  resources :resources do
    member do
      get :browse
      get :edit_permissions #mongo# TODO
      put :update_permissions #mongo# TODO
      get :to_snapshot # TODO post ??
      post :media_sets
    end
    collection do
      get :favorites, :to => "resources#index"
      get :keywords #mongo# TODO
    end
  end

  resources :users do
    member do
      get :usage_terms
      post :usage_terms
    end
    collection do
      get :usage_terms
    end
  end

  resources :people

  resources :groups do
    member do
      post :membership
      delete :membership
    end
  end

  # TODO plural resources nesting upload_session:id
  resource :upload, :controller => 'upload' do
    member do
      post :set_permissions # TODO use update method for all ??
      post :set_media_sets
      get :set_media_sets # TODO :get as well ??
      get :import_summary
    end
  end
  
end
