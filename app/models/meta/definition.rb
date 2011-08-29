# -*- encoding : utf-8 -*-
module Meta
  class Definition
    include Mongoid::Document
    
    embedded_in :meta_context, class_name: "Meta::Context"
    belongs_to :meta_key, class_name: "Meta::Key"
    belongs_to :label, class_name: "Meta::Term"
    belongs_to :description, class_name: "Meta::Term"
    belongs_to :hint, class_name: "Meta::Term"

    key :meta_key_id

    field :is_required, type: Boolean
    field :length_min, type: Integer
    field :length_max, type: Integer
#mongo# TODO ??    
#    field :key_map
#    field :key_map_type
#    field :position

    validates_presence_of :meta_key_id    
    
  end
end
