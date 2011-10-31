# -*- encoding : utf-8 -*-
module Meta
  class Term
    include Mongoid::Document

    LANGUAGES = [:de_CH, :en_GB]
    DEFAULT_LANGUAGE = :de_CH
    
    field :en_GB, type: String
    field :de_CH, type: String

    #really needed??# has_and_belongs_to_many :meta_keys, class_name: "Meta::Key", inverse_of: :meta_terms # NOTE need inverse_of

    has_many :media_resources, class_name: "Media::Resource", foreign_key: "meta_data.meta_keywords.meta_term_id"
    def meta_data
      media_resources.collect(&:meta_data).flatten.select{|md| md.meta_keywords.any? {|x| x.meta_term_id == id }}
    end

    def to_s(lang = nil)
      lang ||= DEFAULT_LANGUAGE
      self.send(lang)
    end

    ######################################################

    def is_used?
      false #mongo# TODO self.class.used_ids.include?(self.id)
    end

=begin #mongo#  
    # TODO method cache
    def self.used_ids
      @used_ids ||= begin
        ids = (MetaContext.all + MetaKeyDefinition.all).collect do |x|
          # TODO fetch id directly
          [x.meta_field.label.try(:id), x.meta_field.description.try(:id), x.meta_field.hint.try(:id)]
        end
        ids += MetaKey.for_meta_terms.collect(&:used_term_ids)
        ids += Keyword.select(:meta_term_id).group(:meta_term_id).collect(&:meta_term_id)
        ids.flatten.uniq.compact
      end
    end
=end
  
    #########################################################

    def self.for_s(s)
      r = Meta::Term.where(DEFAULT_LANGUAGE => s).first
      r ||= begin
        r2 = nil
        LANGUAGES.each do |lang|
          next if lang == DEFAULT_LANGUAGE
          r2 ||= Meta::Term.where(lang => s).first
        end
        r2
      end
      r ||= Meta::Term.create(DEFAULT_LANGUAGE => s)
    end
    
  end
end
