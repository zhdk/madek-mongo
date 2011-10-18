# -*- encoding : utf-8 -*-
module Meta
  class Key
    include Mongoid::Document
    
    key :label
    field :label, type: String
    field :object_type, type: String #mongo# TODO
    field :is_dynamic, type: Boolean #, default: false #mongo# TODO
    field :is_extensible_list, type: Boolean #, default: false #mongo# TODO
    
    index :object_type

    has_and_belongs_to_many :meta_terms, class_name: "Meta::Term", inverse_of: :meta_keys # NOTE need inverse_of
    
    # Mongoid::Errors::MixedRelations: Referencing a(n) Meta::Datum document from the Meta::Key
    # document via a relational association is not allowed since the Meta::Datum is embedded.  
    # has_many :meta_data, :class_name => "Meta::Datum"
    has_many :media_resources, class_name: "Media::Resource", foreign_key: "meta_data._id"
    #mongo# OPTIMIZE
    def meta_data
      #tmp# media_resources.collect(&:meta_data).flatten.select{|md| md.meta_key_id == id}
      media_resources.fields(:meta_data => 1).collect{|mr| mr.meta_data.where(:_id => id) }.flatten
    end

    has_many :meta_contexts, class_name: "Meta::Context", foreign_key: "meta_definitions.meta_key_id"
    #mongo# OPTIMIZE
    def meta_definitions
      meta_contexts.fields(:meta_definitions => 1).collect{|mc| mc.meta_definitions.where(:meta_key_id => id) }.flatten
    end

  ########################################################

    def all_context_labels
      #meta_key_definitions.collect {|d| "#{d.meta_context}: #{d.meta_field.label}" if d.key_map.blank? }.compact.join(', ')
      meta_definitions.collect {|d| d.label if d.key_map.blank? }.compact.uniq.join(', ')
    end

    ########################################################
    
    # Return a meta_key matching the provided key-map
    #
    # args: a keymap (fully namespaced)
    # returns: a meta_key
    #
    # NB: If no meta_key matching the key-map is found, it is created 
    # along with a new meta_key_definition (albeit with minimal label and description data)
    def self.meta_key_for(key_map) # TODO, context = nil)
      # do we really need to find by context here?
      
      #mk = if context.nil?
      #       MetaKeyDefinition.find_by_key_map(key_map).try(:meta_key)
      #     else
      #       context.meta_key_definitions.find_by_key_map(key_map).try(:meta_key)
      #     end
  
      #old# mk = MetaKeyDefinition.where("key_map LIKE ?", "%#{key_map}%").first.try(:meta_key)
      mk = Meta::Context.io_interface.meta_definitions.where(:key_map => key_map).first.try(:meta_key)

      if mk.nil?
        entry_name = key_map.split(':').last.underscore.gsub(/[_-]/,' ')
        mk = Meta::Key.where(:label => entry_name).first
      end
        # we have to create the meta key, since it doesnt exist
      if mk.nil?
        mk = Meta::Key.find_or_create_by(:label => entry_name)
        mc = Meta::Context.io_interface
  
        # Would be nice to build some useful info into the meta_field for this new creation.. but we know nothing about it apart from its namespace:tagname
        meta_field = { :label => {:en_GB => "", :de_CH => ""},
                       :description => {:en_GB => "", :de_CH => ""}
                     }

        mk.meta_key_definitions.create( :meta_context => mc,
                                        :meta_field => meta_field,
                                        :key_map => key_map,
                                        :key_map_type => nil,
                                        :position => mc.meta_key_definitions.maximum("position") + 1 )
      end
      mk
    end
    
  end
end
