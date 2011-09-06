# -*- encoding : utf-8 -*-
class ResourcesController < ApplicationController
  #tmp# respond_to :html, :js
  
  load_resource :class => "Media::Resource"
  #load_and_authorize_resource :class => "Media::Resource"

  def index
    can_action = params[:can] ? params[:can].to_sym : :read
    resources = Media::Resource.accessible_by(current_ability, can_action).page(params[:page])
    resources = resources.where(:_id.in => current_user.favorite_resource_ids) if request.fullpath =~ /favorites/
    resources = resources.csearch(params[:query]) unless params[:query].blank?

    @json = { :pagination => { :current_page => resources.current_page,
                               :per_page => resources.size,
                               :total_entries => resources.total_count,
                               :total_pages => resources.num_pages },
              :entries => resources.as_json({:user => current_user, :ability => current_ability}) }.to_json

    ################################################

    respond_to do |format|
      format.html
      format.js { render :json => @json }
    end
    #tmp# respond_with @resources
  end

  def show
    authorize! :read, @resource => Media::Resource

    if @resource.is_a? Media::Set
      resources = @resource.media_resources.accessible_by(current_ability).page(params[:page])
      #resources = resources.csearch(params[:query]) unless params[:query].blank?
      @json = { :pagination => { :current_page => resources.current_page,
                                 :per_page => resources.size,
                                 :total_entries => resources.total_count,
                                 :total_pages => resources.num_pages },
                :entries => resources.as_json({:user => current_user, :ability => current_ability}) }.to_json
    end

    respond_to do |format|
      format.html
    end
    #tmp# respond_with @resource
  end

  def edit
    authorize! :update, @resource => Media::Resource

    respond_to do |format|
      format.html
    end
    #tmp# respond_with @resource
  end

  def update
    authorize! :update, @resource => Media::Resource

    #mongo# if @resource.update_attributes(params[:resource], current_user)
    if @resource.update_attributes(params[:resource])
      flash[:notice] = "Die Änderungen wurden gespeichert."
    else
      flash[:error] = "Die Änderungen wurden nicht gespeichert."
    end

    respond_to do |format|
      format.html {
        #mongo#
        #if @resource.is_a? Snapshot
        #  redirect_to snapshots_path
        #else
          redirect_to :action => :show
        #end
      }
    end
  end

############################################################################################

  def browse
    # TODO merge with index/show
    authorize! :read, @resource => Media::Resource

    #@viewable_resources = Media::Resource.accessible_by(current_ability)
    @viewable_media_entries = Media::Entry.accessible_by(current_ability)
  end

############################################################################################

  def keywords
    @all_keywords = [] #mongo# TODO Keyword.select("*, COUNT(*) AS q").group(:meta_term_id).order("q DESC")
    @my_keywords = [] #mongo# TODO Keyword.select("*, COUNT(*) AS q").where(:user_id => current_user).group(:meta_term_id).order("q DESC")
        
    respond_to do |format|
      format.html
      format.js { render :layout => false }
    end
  end

end
