# -*- encoding : utf-8 -*-
module Meta
  class Datum
    include Mongoid::Document

    key :meta_key_id
    field :value, type: String #, type: Array, default: [] #mongo# TODO embeds_many :meta_strings ??

    embedded_in :media_resources, class_name: "Media::Resource"
    embeds_many :meta_keywords, class_name: "Meta::Keyword"
    embeds_many :meta_references, class_name: "Meta::Reference" #mongo# TODO merge meta_keywords into meta_references
    embeds_many :meta_dates, class_name: "Meta::Date"
    belongs_to :meta_key, class_name: "Meta::Key" #mongo# , index: true #mongo# index :meta_key_id, unique: true

    validates_presence_of :meta_key_id

    #########################################################

    def to_s
      if not meta_keywords.blank?
        meta_keywords.collect(&:to_s).join(', ')
      elsif not meta_references.blank?
        meta_references.collect(&:to_s).join(', ')
      elsif not meta_dates.blank?
        meta_dates.collect(&:to_s).join(', ')
      else
        "#{value}"
      end
    end

  end
end
