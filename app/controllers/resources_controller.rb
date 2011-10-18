# -*- encoding : utf-8 -*-
class ResourcesController < ApplicationController
  #tmp# respond_to :html, :js
  
  load_resource :class => "Media::Resource"
  #load_and_authorize_resource :class => "Media::Resource"

  def index
    can_action = params[:can] ? params[:can].to_sym : :read
    klass = case params[:type]
              when "entry"
                Media::Entry
              when "set"
                Media::Set
              else
                Media::Resource
            end
    resources = klass.accessible_by(current_ability, can_action).page(params[:page])
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
    # FIXME doens't work !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
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
      format.html {}
      format.js { render :partial => "edit_context" }
    end
    #tmp# respond_with @resource
  end

  def update
    authorize! :update, @resource => Media::Resource

    if @resource.update_attributes(params[:resource], current_user)
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

  def destroy
    authorize! :update, @resource => Media::Resource

    @resource.destroy

    respond_to do |format|
      format.html { 
        flash[:notice] = _("Der Medieneintrag wurde gelöscht.")
        redirect_back_or_default(resources_path)
      }
      format.js { render :json => {:id => @resource.id} }
    end
  end

############################################################################################

  def edit_permissions
    authorize! :manage_permissions, @resource => Media::Resource

    #mongo# TODO move to Permission#as_json
    permission = @resource.permission
    keys = Permission::ACTIONS
    # OPTIMIZE
    @permissions_json = { "public" => {:view => false, :edit => false, :hi_res => false, :manage_permissions => false, :name => "Öffentlich", :type => 'nil'},
                          "Person" => [],
                          "Group" => [] }

    all_subjects = permission.subject_ids
    all_subjects.each do |subject_id|
      if subject_id == :public
        keys.each {|key| @permissions_json["public"][key] = permission.send(key)["true"].include?(:public) }
      else
        subject = Subject.find(subject_id)
        @permissions_json[subject._type] << begin
          h = {:id => subject.id, :name => subject.to_s, :type => subject._type}
          keys.each {|key| h[key] = permission.send(key)["true"].include?(subject.id) }
          h
        end
      end
    end
    @permissions_json = @permissions_json.to_json
        
    respond_to do |format|
      format.html
      format.js { render :partial => "permissions/edit_multiple" }
    end
  end

  #mongo# merge with update ??
  # OPTIMIZE
  def update_permissions
    authorize! :manage_permissions, @resource => Media::Resource

    if(actions = params[:subject]["nil"])
      actions.each_pair do |action, boolean|
        @resource.permission.send((boolean.to_s == "true" ? :grant : :deny), {action => :public}) 
      end
    end
    # TOOD drop and merge to Subject
    ["Person", "User", "Group"].each do |key|
      params[:subject][key].each_pair do |subject_id, actions|
        subject = Subject.find(subject_id)
        # OPTIMIZE it's not sure that the current_user is the owner (manager) of the current resource # TODO use Permission.assign_manage_to ?? 
        actions[:manage_permissions] = true if subject == current_user
        actions.each_pair do |action, boolean|
          @resource.permission.send((boolean.to_s == "true" ? :grant : :deny), {action => subject}) 
        end
      end if params[:subject][key]
    end

    flash[:notice] = _("Die Zugriffsberechtigungen wurden erfolgreich gespeichert.")  
    redirect_to :action => :show
  end

############################################################################################

  def browse
    # TODO merge with index/show
    authorize! :read, @resource => Media::Resource
  end

############################################################################################

  # TODO only for Media::Entry
  def to_snapshot
    # TODO authorize! :snapshot, @resource => Media::Resource

    @resource.to_snapshot if current_user.groups.is_member?("Expert")
    redirect_to :action => :show
  end

############################################################################################

  def media_sets
    if request.post?
      Media::Set.find_by_id_or_create_by_title(params[:media_set_ids], current_user).each do |media_set|
        next unless can?(:update, media_set => Media::Resource)
        media_set.media_resources << @resource #mongo# TODO media_set.media_resources.push_uniq @media_entry
      end
      redirect_to :action => :show
    elsif request.delete?
      @media_set = Media::Set.find(params[:media_set_id]) unless params[:media_set_id].blank?
      if can?(:update, @media_set => Media::Resource)
        @media_set.media_resources.delete(@resource)
        render :nothing => true # TODO redirect_to @media_set
      else
        # OPTIMIZE
        render :nothing => true, :status => 403
      end 
    end
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
