# -*- encoding : utf-8 -*-
class Admin::ContextsController < Admin::AdminController

  before_filter :pre_load

  def index
    hard_sort = %w(io_interface tms core upload media_content media_object copyright zhdk_bereich media_set)
    @contexts = Meta::Context.all.sort {|a,b| (hard_sort.index(a.name) || a.id).to_s <=> (hard_sort.index(b.name) || b.id).to_s }
  end

  def new
    @context = Meta::Context.new
    respond_to do |format|
      format.js
    end
  end

  def create
    Meta::Context.create(params[:meta_context])
    redirect_to admin_contexts_path
  end

  def edit
    respond_to do |format|
      format.js
    end
  end

  def update
    @context.update_attributes(params[:meta_context])
    redirect_to admin_contexts_path
  end

  def destroy
    @context.destroy    
    redirect_to admin_contexts_path
  end
  
#####################################################

  private

  def pre_load
      params[:context_id] ||= params[:id]
      @context = Meta::Context.find(params[:context_id]) unless params[:context_id].blank?
  end

end
