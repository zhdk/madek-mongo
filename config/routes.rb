MAdeKMongo::Application.routes.draw do

  root :to => "application#root"

##############################################################################################
  
  match '/help', :to => "application#help"
  match '/feedback', :to => "application#feedback"

  match '/login', :to => "authenticator/zhdk#login"
  match '/logout', :to => "authenticator/zhdk#logout"
  match '/db/login', :to => "authenticator/database_authentication#login"
  match '/db/logout', :to => "authenticator/database_authentication#logout"
  match '/authenticator/zhdk/login_successful/:id', :to => "authenticator/zhdk#login_successful"

##############################################################################################

  match '/import', :to => Upload::Import
  match '/upload.js', :to => Upload::Import
  match '/upload_estimation.js', :to => Upload::Estimation
  match '/download', :to => Download
  match '/nagiosstat', :to => Nagiosstat
  
##############################################################################################

  # TODO shallow ??
  resources :media_sets do
    resources :resources
  end

  resources :resources do
    collection do
      get :favorites, :to => "resources#index"
      get :keywords #mongo# TODO
      post :filter, :to => "resources#index"
      #working here#
      post :edit_multiple
      put :update_multiple
      post :edit_multiple_permissions
      get :export_tms
      put :update_permissions
    end
    member do
      get :browse
      get :edit_permissions
      put :update_permissions
      get :to_snapshot # TODO post ??
      post :media_sets
      post :toggle_favorites
      #working here#
      post :add_member
    end
  end

  resources :users do
    collection do
      get :usage_terms
    end
    member do
      get :usage_terms
      post :usage_terms
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

##############################################################################################

  namespace :admin do
    root :to => "keys#index"
    
    resource :meta, :controller => 'meta' do
      member do
        get :export
        get :import
        post :import
      end
    end

    resources :keys do
      collection do
        get :mapping
      end
    end

    resources :contexts do
      resources :definitions do
        collection do
          put :reorder
        end
      end
    end

    resources :terms
    
    resources :users do
      member do
        get :switch_to
      end
    end

    resources :people

    resources :groups do
      resources :users do
        member do
          post :membership
          delete :membership
        end
      end
    end

    resource :usage_term

    resources :media_entries do
      collection do
        get :import
      end
    end

    resources :media_sets do
      collection do
        get :featured
        post :featured
      end
    end
  end
  
end
