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
      # 10262 => Ramon Cahenzli
      # 10301 => Susanne Schumacher
      # 159123 => Franco Sellitto
      if [10262, 10301, 159123].include?(current_user.id)
        required_group.users << current_user
      else
        flash[:error] = "The function you wish to use is only available to admin users"
        redirect_to root_path
      end
    end
  end
  
end
