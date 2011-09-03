# -*- encoding : utf-8 -*-
module Meta
  class Datum
    include Mongoid::Document

    key :meta_key_id
    field :text, type: String #, type: Array, default: [] #mongo# TODO embeds_many :meta_strings ??
    attr_accessor :value #mongo#

    embedded_in :media_resources, class_name: "Media::Resource"
    embeds_many :meta_keywords, class_name: "Meta::Keyword"
    embeds_many :meta_references, class_name: "Meta::Reference" #mongo# TODO merge meta_keywords into meta_references
    embeds_many :meta_dates, class_name: "Meta::Date"
    belongs_to :meta_key, class_name: "Meta::Key" #mongo# , index: true #mongo# index :meta_key_id, unique: true

    #########################################################

    validates_presence_of :meta_key_id

    #########################################################

    # OPTIMIZE
    scope :for_meta_terms, where(:meta_key_id.in => Meta::Key.where(:object_type => "Meta::Term").collect(&:id)) 

    #########################################################

    before_save do
      #return false if value.nil? #mongo#
      case meta_key.object_type
        when "Meta::Copyright"
          klass = meta_key.object_type.constantize
          if value.class == TrueClass
            self.value = klass.custom
          elsif value.class == FalseClass
            self.value = klass.public
          end
          Array(value).each do |x|
            meta_references.build(:reference => x)
          end
        when "Meta::Department"
          # TODO Meta::Department as subclass of group ??
          Array(value).each do |x|
            meta_references.build(:reference => x)
          end
        when "Person"
          klass = meta_key.object_type.constantize
          Array(value).each do |x|
            if x.is_a? String
              #self.value = klass.split(Array(value))
              firstname, lastname = klass.parse(x)
              x = klass.find_or_create_by(:firstname => firstname.try(:capitalize), :lastname => lastname.try(:capitalize)) if firstname or lastname
            end
            meta_references.build(:reference => x)
          end
        when "Meta::Term"
          Array(value).each do |x|
            meta_keywords.build(:meta_term => x)
          end
        when "Meta::Keyword"
          Array(value).each do |x|
            if x.is_a? String
              meta_keywords.build(:meta_term => x)
            else
              meta_keywords.build(x)
            end
          end
        when "Meta::Date"
          # TODO use Ruby Date directly ??
          Array(value).each do |x|
            meta_dates.build(x)
          end
        when "Meta::Country"
          # TODO define a country class ??
          self.text = value
        else
          self.text = value
      end
    end

    #mongo# TODO merge to_s
    def value
      case meta_key.try :object_type
        when "Meta::Copyright", "Meta::Department", "Person"
          meta_references.map(&:to_s)
        when "Meta::Term", "Meta::Keyword"
          meta_keywords.map(&:to_s)
        when "Meta::Date"
          meta_dates.map(&:to_s)
        when "Meta::Country"
          text
        else
          text
      end
    end

    #########################################################

    def to_s
      if not meta_keywords.blank?
        meta_keywords.collect(&:to_s).join(', ')
      elsif not meta_references.blank?
        meta_references.collect(&:to_s).join(', ')
      elsif not meta_dates.blank?
        meta_dates.collect(&:to_s).join(', ')
      else
        "#{text}"
      end
    end

  end
end
