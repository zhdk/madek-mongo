# -*- encoding : utf-8 -*-
module Meta
  class Context
    include Mongoid::Document

    key :name # FIXME what happens to the references if the name changes ??
    field :name, type: String
    field :is_user_interface, type: Boolean, default: true

    #########################################################

    embeds_many :meta_definitions, class_name: "Meta::Definition"
    belongs_to :label, class_name: "Meta::Term"
    belongs_to :description, class_name: "Meta::Term"
    
    def meta_keys(for_meta_terms = false)
      r = meta_definitions.collect(&:meta_key)
      if for_meta_terms
        r.select {|mk| mk.object_type == "Meta::Term"}
      else
        r
      end
    end
    def meta_key_ids
      meta_definitions.collect(&:meta_key_id)
    end

    #########################################################
    
    after_save do
      generate_exiftool_config if name == "io_interface"
    end

    #########################################################
    
    scope :for_interface, where(:is_user_interface => true)
    scope :for_import_export, where(:is_user_interface => false)
    
    #########################################################

=begin
    def label=(h)
      binding.pry
      #@label = Meta::Term.for(h)
    end

    def description=(h)
      binding.pry
      #@description = Meta::Term.for(h)      
    end
=end

    def update_attributes_with_pre(new_attributes)
      if(label = new_attributes.delete(:label))
        self.label = Meta::Term.for(label) 
      end
      if(description = new_attributes.delete(:description))
        self.description = Meta::Term.for(description) 
      end
      update_attributes_without_pre(new_attributes)
    end
    alias_method_chain :update_attributes, :pre

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

    #########################################################

    private
    
    # ad-hoc method that generates a new exiftool config file, when it is sensed that there are new keys/key_defs that should be saved in a file
    # using the XMP-madek metadata namespace.
    def generate_exiftool_config
      return if name != "io_interface"
      
      exiftool_keys = meta_definitions.collect {|e| "#{e.key_map.split(":").last} => {#{e.key_map_type == "Array" ? " List => 'Bag'" : nil} },"}
  
      skels = Dir.glob("#{Media::Resource::METADATA_CONFIG_DIR}/ExifTool_config.skeleton.*")
  
      exif_conf = ::File.open(Media::Resource::EXIFTOOL_CONFIG, 'w')
      exif_conf.puts IO.read(skels.first)
      exiftool_keys.sort.each do |k|
        exif_conf.puts "\t#{k}\n"
      end
      exif_conf.puts IO.read(skels.last)
      exif_conf.close
    end


  end
end
