# -*- encoding : utf-8 -*-
class Group < Subject

  has_and_belongs_to_many :people

  field :name, type: String
    
end