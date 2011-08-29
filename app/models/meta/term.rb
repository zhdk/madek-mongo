# -*- encoding : utf-8 -*-
module Meta
  class Term
    include Mongoid::Document
    
    field :en_GB, type: String
    field :de_CH, type: String

    #really needed??# has_and_belongs_to_many :meta_keys, class_name: "Meta::Key", inverse_of: :meta_terms # NOTE need inverse_of

    has_many :media_resources, class_name: "Media::Resource", foreign_key: "meta_data.meta_tags.meta_term_id"
    def meta_data
      media_resources.collect(&:meta_data).flatten.select{|md| md.meta_tags.any? {|x| x.meta_term_id == id }}
    end

    def to_s #(lang = nil)
      #lang ||= DEFAULT_LANGUAGE
      #self.send(lang)
      de_CH
    end
    
  end
end
