# -*- encoding : utf-8 -*-
class EditSession
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  embedded_in :media_resource, class_name: "Media::Resource"
  belongs_to :subject
  
  key :subject_id

  ##########################################################

  validates_presence_of :subject

  default_scope order_by([:created_at, :desc])

end
