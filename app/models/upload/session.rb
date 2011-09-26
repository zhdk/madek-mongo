# -*- encoding : utf-8 -*-
module Upload
  class Session #mongo# TODO subclass to Media::Set ??
    include Mongoid::Document
    include Mongoid::Timestamps::Created
  
    has_many :media_entries, class_name: "Media::Entry", dependent: :destroy, inverse_of: :upload_session # NOTE need inverse_of
    #old# belongs_to :person, class_name: "Person"
    embedded_in :person, class_name: "Person"
    
    field :is_complete, type: Boolean #mongo# TODO
    
    #old# validates_presence_of :person_id
  
    default_scope order_by([:created_at, :desc])

    #########################################################
  
    def to_s
      # TODO cached count column for media_entries
      "#{created_at.to_formatted_s(:date_time)} (#{media_entries.count})"
    end
    
  end
end
