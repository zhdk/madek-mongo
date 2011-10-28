# -*- encoding : utf-8 -*-
class Admin::MediaSetsController < Admin::AdminController
  
  before_filter :pre_load

  def index
    @sets = Media::Set.all
  end

  def new
    @set = Media::Set.new
    respond_to do |format|
      format.js
    end
  end

  def create
    type = params[:media_set].delete(:type)
    set = type.constantize.create(:user => current_user)
    set.update_attributes(params[:media_set])
    redirect_to admin_media_sets_path
  end

  def edit
    respond_to do |format|
      format.js
    end
  end

  def update
    if params[:individual_contexts] and @set.respond_to? :individual_contexts
      @set.individual_contexts = Meta::Context.find(params[:individual_contexts])
    end
    
    #mongo# FIXME
    type = params[:media_set].delete(:type)
    unless @set.respond_to?(:individual_contexts)
      # here we are allowing for a one-way conversion of Media::Set into Media::Project
      @set.type = type # can't usually mass assign the type attribute
      @set.attributes = params[:media_set]
      @set.save
    else
      @set.update_attributes(params[:media_set])
    end
    
    unless params[:new_manager_user_id].blank?
      user = User.find(params[:new_manager_user_id])
      Permission.assign_manage_to(user, @set, !!params[:with_media_entries])
    end
    
    redirect_to admin_media_sets_path
  end

  def destroy
    @set.destroy if @set.media_entries.empty?
    redirect_to admin_media_sets_path
  end

#####################################################

  def featured
    @set = Media::Set.featured.first || Media::Set.new(:is_featured => true)
    if request.post?
      if @set.new_record?
        @set.default_permission=({:view => true})
        #old# @set.save
      end
      #old# @set.media_resources.delete_all
      #old# @set.media_resources << Media::Set.find(params[:children]) unless params[:children].blank?
      @set.media_resource_ids.clear
      params[:children].each {|s| @set.media_resource_ids << BSON::ObjectId.from_string(s)} unless params[:children].blank?
      @set.save
    end
  end

#####################################################

  private

  def pre_load
      params[:media_set_id] ||= params[:id]
      @set = Media::Set.find(params[:media_set_id]) unless params[:media_set_id].blank?
  end
  
end
