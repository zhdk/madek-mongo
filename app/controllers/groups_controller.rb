# -*- encoding : utf-8 -*-
class GroupsController < ApplicationController

  #mongo# before_filter :pre_load
  #mongo# before_filter :authorized?, :only => [:edit, :update, :destroy]
  load_resource

  def index
    # OPTIMIZE
    respond_to do |format|
      format.html {
        @groups = current_user.groups
      }
      format.js {
        # OPTIMIZE index groups to sphinx ??
        #mongo# groups = Group.where("name LIKE :term OR ldap_name LIKE :term", {:term => "%#{params[:term]}%"})
        #mongo# render :json => groups.map {|x| {:id => x.id, :value => x.to_s} }
      }
    end
  end

  def new
    @group = current_user.groups.build
  end

  def create
    group = current_user.groups.build(params[:group])
    if group.save
      group.people << curent_user unless group.people.include?(current_user)
      redirect_to edit_group_path(group)
    else
      flash[:error] = group.errors.full_messages
      redirect_to :back
    end
  end

  def edit
    # TODO authorized?
  end

  def update
    # TODO authorized?
    @group.update_attributes(params[:group])
    respond_to do |format|
      format.html { redirect_to edit_group_path(@group) }
      format.js { render :text => @group.name } # OPTIMIZE
    end
  end

  def destroy
    @group.destroy
    redirect_to groups_path
  end

######################################################

  # TODO refactor to update method and use accepted_nested_attributes ?? 
  def membership
    @user = Person.find(params[:user_id])
    if request.post?
      @group.people << @user
      respond_to do |format|
        format.js { render :partial => "user", :object => @user }
      end
    elsif request.delete?
      @group.people.delete(@user)
      respond_to do |format|
        format.js { render :nothing => true } # TODO check if successfully deleted
      end
    end
  end

######################################################

=begin

  private

  def authorized?
    not_authorized! if @group.is_readonly?
  end

  def pre_load
    params[:group_id] ||= params[:id]
    @group = current_user.groups.find(params[:group_id]) unless params[:group_id].blank?
  end
=end

end
