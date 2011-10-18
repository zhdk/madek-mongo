# -*- encoding : utf-8 -*-
class Ability
  include CanCan::Ability

  def initialize(user)
    
    ids = [:public, user.try(:group_ids), user.try(:id)].flatten.uniq
    
    # TODO prioriy check, see below
    # TODO map_reduce ??

    ####################################
    can :read, Media::Resource, :"permission.view.true".in => ids
    # cannot :read, Media::Resource, :"permission.view.false".in => ids

    ####################################
    can :update, Media::Resource, :"permission.edit.true".in => ids

    ####################################
    can :hi_res, Media::Resource, :"permission.hi_res.true".in => ids

    ####################################
    can :manage_permissions, Media::Resource, :"permission.manage_permissions.true".in => ids
    
  end

=begin
  1. add public resources:  [1,2,3,4,6] => [1,2,3,4,6] 
  2. remove group false:    [2,6] => [1,3,4]
  3. add group true:        [1,2,5] => [1,2,3,4,5]
  4. remove user false:     [2,5] => [1,3,4]
  5. add user true:         [3,6] => [1,3,4,6]

  current permissions:
  ((user_groups_true - user_false) + (public_true - user_groups_false)).uniq
  ([1,2,3,5,6] - [2,5]) + ([1,2,3,4,6] - [2,5,6])
  [1,3,6] + [1,3,4]
  [1,3,4,6]
  
  ======
  Can the current_user view the current a media_entry?
  1. get permission for public on current media_entry 
    1.1. if doesn't exist, go to 2
    1.2. if exists
      1.2.1. if view action is true, return true (current_user has access) (exclusion are not possible)
      1.2.2. else if view action is false or not defined, go to 2
  2. get permission for current_user on current media_entry
    2.1. if doesn't exist, go to 3
    2.2. if exists
      2.2.1. if view action is true, return true (current_user has access)
      2.2.2. else if view action is false, return false (current_user doesn't have access)
      2.2.3. else if view action is not defined, go to 3
  3. get permissions on current_media for all groups which current_user is member of 
    3.1. if don't exist, return false (current_user doesn't have access)
    3.2. if exist get the union of the view action among all found permissions
      3.2.1. if there is at least one view action set to true, return true (current_user has access)
      3.2.2. else if all view actions are false or not defined, return false (current_user doesn't have access)
=end
  
end
