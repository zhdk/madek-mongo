# -*- encoding : utf-8 -*-
class ResourcesController < ApplicationController
  #tmp# respond_to :html, :js
  
  load_resource :class => "Media::Resource"
  #load_and_authorize_resource :class => "Media::Resource"

  def index
    can_action = params[:can] ? params[:can].to_sym : :read

    @media_set = Media::Set.find(params[:media_set_id]) unless params[:media_set_id].blank?
    klass = if @media_set
      @media_set.media_resources
    else
      Media::Resource
    end
    klass = case params[:type]
      when "entry"
        klass.media_entries.where(:is_snapshot.in => [nil, false])
      when "snapshot"
        klass.media_entries.where(:is_snapshot => true)
      when "set"
        klass.media_sets.where(:is_snapshot.in => [nil, false])
      else
        klass.where(:is_snapshot.in => [nil, false])
    end
    resources = klass.accessible_by(current_ability, can_action).page(params[:page])
    resources = resources.where(:_id.in => current_user.favorite_resource_ids) if request.fullpath =~ /favorites/
    unless params[:query].blank?
      resources = resources.csearch(params[:query])
      #mongo#dirty# OPTIMIZE filter
      @_resource_ids = resources.only(:_id).limit(nil).map(&:_id)
    end
    
    if params[:filter]
      ids = params[:filter][:ids].split(',')
      resources = resources.where(:_id.in => ids)
    end

    @results = { :pagination => { :current_page => resources.current_page,
                               :total_entries => resources.total_count,
                               :total_pages => resources.num_pages },
              :entries => resources.as_json({:user => current_user, :ability => current_ability}) }

    respond_to do |format|
      format.html
      format.js { render :json => @results }
    end
    #tmp# respond_with @resources
  end

  def show
    # FIXME doens't work !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    authorize! :read, @resource => Media::Resource

    if @resource.is_a? Media::Set
      resources = @resource.media_resources.accessible_by(current_ability).page(params[:page])
      #resources = resources.csearch(params[:query]) unless params[:query].blank?
      @results = { :pagination => { :current_page => resources.current_page,
                                 :total_entries => resources.total_count,
                                 :total_pages => resources.num_pages },
                :entries => resources.as_json({:user => current_user, :ability => current_ability}) }
    end

    respond_to do |format|
      format.html { redirect_to edit_resource_path(@resource) if @resource.is_snapshot }
      format.tms { render :xml => Media::Resource.to_tms_doc(@resource) }
    end
    #tmp# respond_with @resource
  end

  def edit
    authorize! :update, @resource => Media::Resource

    @is_expert = current_user.groups.is_member?("Expert")

    params[:context] = "tms" if @resource.is_snapshot
    @meta_contexts = if params[:context] == "tms"
      authorize! :edit_tms, @resource => Media::Resource
      [Meta::Context.tms]
    else
      Meta::Context.default_contexts + @resource.individual_contexts
    end

    respond_to do |format|
      format.html {}
      #mongo# TODO still needed ?? format.js { render :partial => "edit_context" }
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
        path = if @resource.is_snapshot
          resources_path(:type => :snapshot)
        else
          resources_path
        end
        redirect_back_or_default(path)
      }
      format.js { render :json => {:id => @resource.id} }
    end
  end

############################################################################################

  #wip#4 merge to Permission#compare
  def edit_permissions
    authorize! :manage_permissions, @resource => Media::Resource

    #mongo# TODO move to Permission#as_json
    permission = @resource.permission
    # OPTIMIZE
    @permissions_json = { "public" => {:view => false, :edit => false, :hi_res => false, :manage_permissions => false, :name => "Öffentlich", :type => 'nil'},
                          "Person" => [],
                          "Group" => [] }

    all_subjects = permission.subject_ids
    all_subjects.each do |subject_id|
      if subject_id == :public
        Permission::ACTIONS.each {|key| @permissions_json["public"][key] = permission.send(key)["true"].include?(:public) }
      else
        subject = Subject.find(subject_id)
        @permissions_json[subject._type] << begin
          h = {:id => subject.id, :name => subject.to_s, :type => subject._type}
          Permission::ACTIONS.each {|key| h[key] = permission.send(key)["true"].include?(subject.id) }
          h
        end
      end
    end
    @permissions_json = @permissions_json.to_json
        
    respond_to do |format|
      #mongo#old#?? format.html
      format.js { render :partial => "permissions/edit_multiple" }
    end
  end

  #mongo# merge with update ??
  # OPTIMIZE
  def update_permissions
    @resources = if params[:media_entry_ids]
      redirect_back_or_default(resources_path)
      pre_load_for_batch
      @media_entries
    else
      redirect_to resource_path(@resource)
      [@resource]
    end

    @resources.each do |resource|
      authorize! :manage_permissions, resource => Media::Resource
  
      ########## TODO refactor to Permission or Resource
      if(actions = params[:subject]["nil"])
        actions.each_pair do |action, boolean|
          resource.permission.send((boolean.to_s == "true" ? :grant : :deny), {action => :public}) 
        end
      end
      # TOOD drop and merge to Subject
      ["Person", "User", "Group"].each do |key|
        params[:subject][key].each_pair do |subject_id, actions|
          subject = Subject.find(subject_id)
          # OPTIMIZE it's not sure that the current_user is the owner (manager) of the current resource # TODO use Permission.assign_manage_to ?? 
          actions[:manage_permissions] = true if subject == current_user
          actions.each_pair do |action, boolean|
            resource.permission.send((boolean.to_s == "true" ? :grant : :deny), {action => subject}) 
          end
        end if params[:subject][key]
      end
      ##########
    end

    flash[:notice] = _("Die Zugriffsberechtigungen wurden erfolgreich gespeichert.") 
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

############################################################################################

  def toggle_favorites
    current_user.favorite_resources.toggle(@resource)
    respond_to do |format|
      format.js { render :partial => "favorite_link", :locals => {:resource => @resource} }
    end
  end

############################################################################################
# BATCH actions
  before_filter :pre_load_for_batch, :only => [:edit_multiple, :update_multiple, :remove_multiple, :edit_multiple_permissions]

  def remove_multiple
    @media_set.media_entries.delete(@media_entries)
    flash[:notice] = "Die Medieneinträge wurden aus dem Set/Projekt gelöscht."
    redirect_to media_set_url(@media_set)
  end
  
  def edit_multiple
    # custom hash for jQuery json templates
    
    #working here#
    #@info_to_json = @media_entries.map do |me|
    #  me.attributes.merge!(me.get_basic_info(current_user, ["uploaded at", "uploaded by", "keywords", "copyright notice", "portrayed object dates"]))
    #end.to_json
    @info_to_json = @media_entries.as_json({:user => current_user, :ability => current_ability}).to_json
  end

  def update_multiple
    @media_entries.each do |media_entry|
      if media_entry.update_attributes(params[:resource], current_user)
        flash[:notice] = "Die Änderungen wurden gespeichert." # TODO appending success message and resource reference (id, title)
      else
        flash[:error] = "Die Änderungen wurden nicht gespeichert." # TODO appending success message and resource reference (id, title)
      end
    end
    redirect_back_or_default(resources_path)
  end
  
  def edit_multiple_permissions
    @permissions_json = Permission.compare(@media_entries).to_json

    #working here#
    #@media_entries_json = @media_entries.map do |me|
    #  me.attributes.merge!(me.get_basic_info(current_user))
    #end.to_json
    @media_entries_json = @media_entries.as_json({:user => current_user, :ability => current_ability}).to_json
  end

  def pre_load_for_batch
    params.delete_if {|k,v| v.blank? }
    action = request[:action].to_sym
    
    @media_set = Media::Set.find(params[:media_set_id]) unless params[:media_set_id].blank?
    
     if not params[:media_entry_ids].blank?
        selected_ids = params[:media_entry_ids].split(",")
        @media_entries = case action
          when :edit_multiple, :update_multiple
            Media::Entry.accessible_by(current_ability, :update).find(selected_ids)
          when :edit_multiple_permissions, :update_permissions
            Media::Entry.accessible_by(current_ability, :manage_permissions).find(selected_ids)
          when :remove_multiple
            Media::Entry.accessible_by(current_ability, :read).find(selected_ids)
         end
     else
       flash[:error] = "Sie haben keine Medieneinträge ausgewählt."
       redirect_to :back
     end
  end

############################################################################################

  # Reponsible for the export of snapshots of media entries into a zipfile with xml file, for tms (The Museum System)
  # /resources/export_tms?resource_ids[]=1&resource_ids[]=2
  def export_tms
    @snapshots = Media::Entry.where(:is_snapshot => true).find(params[:resource_ids])

    all_good = true
    clxn = []

    @snapshots.each do |snapshot|
      xml = Media::Resource.to_tms_doc(snapshot)

      # not providing the full filename of the media_file to be zipped,
      # since it will be provided to the 3rd party receiving system in the accompanying XML
      # however we do apparently need to supply the suffix for the file. hence the unoptimsed nonsense below.
      file_ext = snapshot.media_file.filename.split(".").last
      filetype_extension = ".#{file_ext}" if Media::File::KNOWN_EXTENSIONS.any? {|e| e == file_ext } #OPTIMIZE
      filetype_extension ||= ""
      timestamp = Time.now.to_i # stops racing below
      filename = [snapshot.id, timestamp ].join("_")
      media_filename  = filename + filetype_extension
      xml_filename    = filename + ".xml"
      path = snapshot.updated_resource_file

      clxn << [ xml, media_filename, xml_filename, path ] if path
      all_good = false unless path
    end

#    zip = xml+file

    if all_good
      race_free_filename = ["snapshot", rand(Time.now.to_i).to_s].join("_") + ".zip" # TODO handle user-provided filename
      Zip::ZipOutputStream.open("#{Media::File::DOWNLOAD_STORAGE_DIR}/#{race_free_filename}") do |zos|
        clxn.each do |snapshot|
          xml, filename, xml_filename, path = snapshot

          zos.put_next_entry(filename)
          zos.print IO.read(path)
          zos.put_next_entry(xml_filename)
          zos.print xml
        end # snapshot
      end # zos

      send_file File.join(Media::File::DOWNLOAD_STORAGE_DIR, race_free_filename), :type => "application/zip"
    else
      flash[:error] = "There was a problem creating the files(s) for export"
      redirect_to snapshots_path # TODO correct redirect path.
    end
  end

############################################################################################

  # only for media_sets
  def abstract
    authorize! :read, @resource => Media::Resource
    respond_to do |format|
      format.js { render :layout => false }
    end
  end

end
