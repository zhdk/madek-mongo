# -*- encoding : utf-8 -*-
module Meta
  class Context
    include Mongoid::Document

    key :name
    field :name, type: String
    field :is_user_interface, type: Boolean, default: true

    #########################################################

    embeds_many :meta_definitions, class_name: "Meta::Definition"
    belongs_to :label, class_name: "Meta::Term"
    belongs_to :description, class_name: "Meta::Term"
    
    def meta_keys
      meta_definitions.collect(&:meta_key)
    end
    def meta_key_ids
      meta_definitions.collect(&:meta_key_id)
    end

    #########################################################

    def to_s
      "#{label}"
    end

    #########################################################

    def self.default_contexts
      [media_content, media_object, copyright, zhdk_bereich]
    end
  
    def self.method_missing(*args)
      r = where(:name => args.first.to_s).first #mongo# TODO use find on :_id
      r || super
    end

  end
end
