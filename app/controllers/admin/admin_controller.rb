# -*- encoding : utf-8 -*-
class Admin::AdminController < ApplicationController

  before_filter :group_required

  layout "admin/main"

##############################################  
  private
  
  def group_required
    # OPTIMIZE
    required_group = Group.find_or_create_by(:name => "Admin")
    unless current_user.groups.is_member?(required_group)
      flash[:error] = "The function you wish to use is only available to admin users"
      redirect_to root_path
    end
  end
  
end
