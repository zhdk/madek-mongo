# -*- encoding : utf-8 -*-
module Meta
  class Datum
    include Mongoid::Document

    field :text, type: String #, type: Array, default: [] #mongo# TODO embeds_many :meta_strings ??

    embedded_in :media_resource, class_name: "Media::Resource"
    embeds_many :meta_keywords, class_name: "Meta::Keyword"
    embeds_many :meta_references, class_name: "Meta::Reference" #mongo# TODO merge meta_keywords into meta_references
    embeds_many :meta_dates, class_name: "Meta::Date"

    #########################################################
    
    #wip#2
    belongs_to :meta_key, class_name: "Meta::Key", foreign_key: :_id # indexed on parent # TODO , foreign_key: :_id ??????
    #key :meta_key_id
    #validates_presence_of :meta_key_id
    validates_presence_of :meta_key
    alias :meta_key_id :id

    #########################################################

    # OPTIMIZE
    #tmp# scope :for_meta_terms, lambda { where(:meta_key_id.in => Meta::Key.where(:object_type => "Meta::Term").collect(&:id)) }
    scope :for_meta_terms, lambda { where(:_id.in => Meta::Key.where(:object_type => "Meta::Term").collect(&:id)) }

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
          mks = Array(@value).collect do |x|
            if x.is_a? String
              meta_keywords.where(:meta_term_id => x).first || meta_keywords.build(:meta_term => Meta::Term.for_s(x))
            else
              meta_keywords.build(x)
            end
          end
          #mongo# FIXME
          (meta_keywords - mks).each {|x| x.delete }
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
      if meta_key.is_dynamic?
        case meta_key.label
          when "uploaded by"
            return media_resource.user
          when "uploaded at"
            return media_resource.created_at #old# .to_formatted_s(:date_time) # TODO media_resource.upload_session.created_at ??
          when "copyright usage"
            copyright = media_resource.meta_data.get("copyright status").value.first || Meta::Copyright.default # OPTIMIZE array or single element
            return copyright.usage(read_attribute(:value))
          when "copyright url"
            copyright = media_resource.meta_data.get("copyright status").value.first  || Meta::Copyright.default # OPTIMIZE array or single element
            return copyright.url(read_attribute(:value))
          #when "public access"
          #  return media_resource.acl?(:view, :all)
          #when "media type"
          #  return media_resource.media_type
          #when "gps"
          #  return media_resource.media_file.meta_data["GPS"]
        end
      else
        case meta_key.object_type
          when "Meta::Copyright", "Meta::Department", "Person"
            meta_references.map(&:reference) #.map(&:to_s)
          when "Meta::Term", "Meta::Keyword"
            meta_keywords.map(&:meta_term) #.map(&:to_s)
          when "Meta::Date"
            meta_dates.map(&:to_s).join(' - ')
          when "Meta::Country"
            text
          else
            text
        end
      end
    end
    
    #########################################################

    def to_s
=begin #old#working here#
      if not meta_keywords.blank?
        meta_keywords.collect(&:to_s).join(', ')
      elsif not meta_references.blank?
        meta_references.collect(&:to_s).join(', ')
      elsif not meta_dates.blank?
        meta_dates.collect(&:to_s).join(', ')
      else
        "#{text}"
      end
=end  
      v = value          
      case v.class.name
        when "Array"
          v.join
        when "Time"
          v.to_formatted_s(:date_time)
        else
          v.to_s
      end
    end

    ##########################################################
  
    def same_value?(other_value)
      case value
        when String
          value == other_value
        when Array
          return false unless other_value.is_a?(Array)
          if value.first.is_a?(Meta::Date) 
            other_value.first.is_a?(Meta::Date) && (other_value.first.free_text == value.first.free_text)
          elsif meta_key.object_type == "Keyword"
            referenced_meta_term_ids = Keyword.where(:id => other_value).all.map(&:meta_term_id)
            deserialized_value.map(&:meta_term_id).uniq.sort.eql?(referenced_meta_term_ids.uniq.sort)
          else
            value.uniq.sort.eql?(other_value.uniq.sort)
          end
        when NilClass
          other_value.blank?
      end
    end

  end
end
