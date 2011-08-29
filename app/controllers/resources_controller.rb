# -*- encoding : utf-8 -*-
class ResourcesController < ApplicationController
  #tmp# respond_to :html, :js
  
  #mongo#
  load_resource :class => "Media::Resource"
  #load_and_authorize_resource :class => "Media::Resource"

  def index
    resources = Media::Resource.accessible_by(current_ability).page(params[:page])
    resources = resources.where(:_id.in => current_user.favorite_resource_ids) if request.fullpath =~ /favorites/
    resources = resources.csearch(params[:query]) unless params[:query].blank?

    #resources = Media::Resource.search("zhdk").accessible_by_subject(user)
    #resources = Media::Resource.accessible_by(current_ability).csearch("zhdk")
    #resources.limit(2).offset(3) #resources.count => total_entries #resources.size => total in page

    #@json = resources.as_json(:except => :_keywords)
    @json = { :pagination => { :current_page => resources.current_page,
                               :per_page => resources.size,
                               :total_entries => resources.total_count,
                               :total_pages => resources.num_pages },
              :entries => resources.as_json({:user => current_user}) }.to_json

    ################################################

    respond_to do |format|
      format.html
      format.js { render :json => @json }
    end
    #tmp# respond_with @resources
  end

  def show
    #@resource = Media::Resource.find(params[:id])
    #@resource = Media::Resource.accessible_by(current_ability).find(params[:id])
    #@resource = current_user.media_entries.find(params[:id])
    authorize! :read, @resource => Media::Resource

    if @resource.is_a? Media::Set
      resources = @resource.media_resources.accessible_by(current_ability).page(params[:page])
      #resources = resources.csearch(params[:query]) unless params[:query].blank?
      @json = { :pagination => { :current_page => resources.current_page,
                                 :per_page => resources.size,
                                 :total_entries => resources.total_count,
                                 :total_pages => resources.num_pages },
                :entries => resources.as_json({:user => current_user}) }.to_json
    end

    respond_to do |format|
      format.html
    end
    #tmp# respond_with @resource
  end

  def edit
    #@resource = Media::Resource.find(params[:id])
    authorize! :update, @resource => Media::Resource

    respond_to do |format|
      format.html
    end
    #tmp# respond_with @resource
  end

end
