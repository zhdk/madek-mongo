# -*- encoding : utf-8 -*-
class UploadController < ApplicationController

##################################################
# step 1

  def new
  end

  def show
    pre_load # OPTIMIZE
  end
  
### metal/upload.rb ###    
#  def create
#  end

##################################################
# step 2

  # TODO dry with PermissionsController#update_multiple
  def set_permissions
    default_params = {:view => false, :edit => false, :hi_res => false}
    params.reverse_merge!(default_params)

    view_action, edit_action, hi_res_download = case params[:view].to_sym
                                  when :private
                                    [default_params[:view], default_params[:edit], default_params[:hi_res]]
                                  when :public
                                    [true, !!params[:edit], true]
                                  else
                                    [default_params[:view], default_params[:edit], default_params[:hi_res]]
                                end
    
    pre_load # OPTIMIZE
    @media_entries.each do |media_entry|
      actions = {:view => view_action, :edit => edit_action, :hi_res => hi_res_download}
      media_entry.default_permission=(actions)
    end

    if params[:view].to_sym == :zhdk_users
      zhdk_group = Group.where(:name => "ZHdK (Zürcher Hochschule der Künste)").first
      actions = {:view => true, :edit => !!params[:edit], :hi_res => true}
      @media_entries.each do |media_entry|
        actions.each_pair do |action, boolean|
          media_entry.permission.send((boolean.to_s == "true" ? :grant : :deny), {action => zhdk_group}) 
        end
      end
    end

    edit
    render :action => :edit
  end


##################################################
# step 3

  def edit
    pre_load
    @context = Meta::Context.upload
  end

  def update
    pre_load
    @upload_session.update_attributes(:is_complete => true)

    params[:resources]["media/entry"].each_pair do |key, value|
      media_entry = @media_entries.detect{|me| me.id.to_s == key } #old# .find(key)
      media_entry.update_attributes(value) # TODO , current_user ??
    end

    # TODO delta index if new Person 

    render :action => :set_media_sets
  end


##################################################
# step 4

  def set_media_sets
    if request.post?
      params[:media_set_ids].delete_if {|x| x.blank?}

      pre_load # OPTIMIZE

      media_sets = Media::Set.find_by_id_or_create_by_title(params[:media_set_ids], current_user)
      media_sets.each do |media_set|
        media_set.media_resources << @media_entries #mongo# TODO media_set.media_resources.push_uniq @media_entries
      end
    
      redirect_to root_path
    else
      # TODO is the get method really needed ??
      pre_load # OPTIMIZE
    end
  end

##################################################

  def import_summary
    pre_load
    @context = MetaContext.upload
    @all_valid = @media_entries.all? {|me| me.context_valid?(@context) }
    @upload_session.update_attributes(:is_complete => true) if @all_valid
  end
  
##################################################

  private
  
  def pre_load
    @upload_session = if params[:upload_session_id]
                        current_user.upload_sessions.find(params[:upload_session_id])
                      else
                        current_user.upload_sessions.most_recent
                      end
    @media_entries = @upload_session.media_entries
  end

end
