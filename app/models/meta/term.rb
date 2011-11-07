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
      media_resources.flat_map(&:meta_data).select{|md| md.meta_keywords.any? {|x| x.meta_term_id == id }}
    end

    def to_s(lang = nil)
      lang ||= DEFAULT_LANGUAGE
      self.send(lang)
    end

    ######################################################

    def is_used?
      # OPTIMIZE use .exists?(conditions: {...}) ??
      self.class.used_ids.include?(self.id)
    end

    # TODO method cache
    def self.used_ids
      # OPTIMIZE use map_reduce ??
      @used_ids ||= begin
        ids = []
        Meta::Context.all.each do |x|
          #MetaKeyDefinition.all
          # TODO fetch id directly
          ids += [x.label_id, x.description_id]
          x.meta_definitions.each do |y|
            ids += [y.label_id, y.description_id, y.hint_id]
          end
        end
        ids += Meta::Key.for_meta_terms.flat_map(&:used_term_ids)
        ids += Meta::Keyword.used_meta_term_ids
        ids.flatten.uniq.compact
      end
    end
  
    #########################################################

    def self.for(h)
=begin
      case h.class 
        when String
          for_s(h)
        when Hash, HashWithIndifferentAccess
        when Meta::Term
          h
        else
          # do nothing
      end
=end
      if h.is_a?(Hash) and !h.values.join.blank?
        find_or_create_by(h)
      end
    end

    def self.for_s(s)
      r = Meta::Term.find(s) if BSON::ObjectId.legal?(s)
      r ||= Meta::Term.where(DEFAULT_LANGUAGE => s).first
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
