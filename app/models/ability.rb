# -*- encoding : utf-8 -*-
class Ability
  include CanCan::Ability

  def initialize(user)
    #guest is nil# user ||= User.new # guest user (not logged in)

    #can :read, Media::Resource, :permissions.matches => {:subject_id => nil, :view => true}
    #if user
    #  can :read, Media::Resource, :permissions.matches => {:subject_id => {"$in" => user.group_ids}, :view => true}
    #  can :read, Media::Resource, :permissions.matches => {:subject_id => user.id, :view => true}
    #  #cannot :read, Media::Resource, :permissions.matches => {:subject_id => user.id, :view => false}
    #end
    
    ids = [nil, user.try(:group_ids), user.try(:id)].flatten.uniq
    
    ####################################
    can :read, Media::Resource, :permissions.matches => {:subject_id => {"$in" => ids}, :view => true}
    #can :read, Media::Resource, "permissions.subject_id" => {"$in" => ids} #, :view => true}
    
    ####################################
    #!!permissions.detect {|x| x.subject_id == user.id and x.edit }
    can :update, Media::Resource, :permissions.matches => {:subject_id => {"$in" => ids}, :edit => true}

    ####################################
    # TODO
    can :hi_res, Media::Resource, :permissions.matches => {:subject_id => {"$in" => ids}, :hi_res => true}

    ####################################
    # TODO
    can :manage, Media::Resource, :permissions.matches => {:subject_id => {"$in" => ids}, :manage => true}
    
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

=begin
s = Media::Resource.where("$or" => [{"$elemMatch" => {:permissions => {:subject_id => nil, :view => true}}},
                                    {"$elemMatch" => {:permissions => {:subject_id => , :view => false}}}])
s = Media::Resource.where({:permissions=>{"$elemMatch"=>{:subject_id=>current_user.id, :view=>true}}})

s = Media::Resource.where({ "permissions" => { "$elemMatch" => { "subject_id" => nil, "view" => true } },
                            "permissions" => {"$not" => { "$elemMatch" => { "subject_id" => current_user.id, "view" => false } } }
                           })

s = Media::Resource.where({ "permissions" => { "$elemMatch" => { "subject_id" => nil, "view" => true } },
                            "permissions" => { "$elemMatch" => { "subject_id" => current_user.id, "view" => false } }
                           })
s = Media::Resource.where({ "permissions" => { "$elemMatch" => { "subject_id" => nil, "view" => true },
                                               "$elemMatch" => { "subject_id" => current_user.id, "view" => false } }
                           })

s = Media::Resource.where({ "permissions" => { "$elemMatch" => { "subject_id" => current_user.group_ids.first, "view" => true } },
                            "permissions" => { "$elemMatch" => { "subject_id" => current_user.id, "view" => false } }
                           })
s = Media::Resource.where({ "permissions" => { "$elemMatch" => { "subject_id" => current_user.group_ids.first, "view" => true },
                                               "$elemMatch" => { "subject_id" => current_user.id, "view" => false } }
                           })
=end
  
end
