# -*- encoding : utf-8 -*-
class Ability
  include CanCan::Ability

  def initialize(user)
    
    ids = [:public, user.try(:group_ids), user.try(:id)].flatten.uniq
    
    ####################################
    can :read, Media::Resource, :"permission.view.true".in => ids
    # TODO prioriy check, see below
    # cannot :read, Media::Resource, :"permission.view.false".in => ids

    ####################################
    can :update, Media::Resource, :"permission.edit.true".in => ids

    ####################################
    # TODO
    can :hi_res, Media::Resource, :"permission.hi_res.true".in => ids

    ####################################
    # TODO
    can :manage, Media::Resource, :"permission.manage.true".in => ids
    
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
=end
  
end
