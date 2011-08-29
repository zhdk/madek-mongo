# -*- encoding : utf-8 -*-
class Subject
  include Mongoid::Document

  # has_many :resources
  # has_many :accessible_resources, :class_name => "Media::Resource", :conditions => ...
=begin
  def accessible_resources #(action = :view)
    Media::Resource.accessible_by_subject(self) #where(:permissions.matches => {:subject_id => self.id, action => true})
  end
=end  
  
end