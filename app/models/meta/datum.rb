# -*- encoding : utf-8 -*-
module Meta
  class Datum
    include Mongoid::Document

    key :meta_key_id
    field :text, type: String #, type: Array, default: [] #mongo# TODO embeds_many :meta_strings ??

    embedded_in :media_resource, class_name: "Media::Resource"
    embeds_many :meta_keywords, class_name: "Meta::Keyword"
    embeds_many :meta_references, class_name: "Meta::Reference" #mongo# TODO merge meta_keywords into meta_references
    embeds_many :meta_dates, class_name: "Meta::Date"
    belongs_to :meta_key, class_name: "Meta::Key" # indexed on parent

    #########################################################

    validates_presence_of :meta_key_id

    #########################################################

    # OPTIMIZE
    scope :for_meta_terms, lambda { where(:meta_key_id.in => Meta::Key.where(:object_type => "Meta::Term").collect(&:id)) }

    #########################################################

    # NOTE before_save is too late!
    before_validation do
      # NOTE first condition on normal edit, second condition on snapshot create 
      return true if @value == value or (@value.nil? and !changed?)

      #return false if @value.nil? #mongo#
      case meta_key.object_type
        when "Meta::Copyright"
          return true if @value.blank? #mongo# OPTIMIZE false
          klass = meta_key.object_type.constantize
          @value = case @value.class
            when TrueClass
              @value = klass.custom
            when FalseClass
              @value = klass.public
          end
          #mongo# OPTIMIZE
          meta_references.delete_all
          Array(@value).each do |x|
            if x.is_a? String
              x = klass.find(x)
            end
            meta_references.build(:reference => x)
          end
        when "Meta::Department"
          Array(@value).each do |x|
            meta_references.build(:reference => x)
          end
        when "Person"
          klass = meta_key.object_type.constantize
          Array(@value).each do |x|
            if x.is_a? String
              #@value = klass.split(Array(@value))
              firstname, lastname = klass.parse(x)
              x = klass.find_or_create_by(:firstname => firstname.try(:capitalize), :lastname => lastname.try(:capitalize)) if firstname or lastname
            end
            meta_references.build(:reference => x)
          end
        when "Meta::Term"
          Array(@value).each do |x|
            meta_keywords.build(:meta_term => x)
          end
        when "Meta::Keyword"
          Array(@value).each do |x|
            if x.is_a? String
              meta_keywords.build(:meta_term => Meta::Term.for_s(x))
            else
              meta_keywords.build(x)
            end
          end
        when "Meta::Date" # TODO use Ruby Date directly ??
          klass = meta_key.object_type.constantize
          Array(@value).each do |x|
            if x.is_a? String
              meta_dates << klass.parse(x)
            else
              meta_dates.build(x)
            end
          end
        when "Meta::Country"
          # TODO define a country class ??
          self.text = @value
        else
          self.text = @value
      end
    end

    #mongo#
    attr_accessor :value
    #def value=(new_value)
    #  self.text = new_value
    #end

    #mongo# TODO merge to_s
    def value
      case meta_key.object_type
        when "Meta::Copyright", "Meta::Department", "Person"
          meta_references.map(&:reference) #.map(&:to_s)
        when "Meta::Term", "Meta::Keyword"
          meta_keywords.map(&:meta_term) #.map(&:to_s)
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
