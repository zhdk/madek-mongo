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

    scope :for_meta_terms, where(:object_type => "Meta::Term") 

    ########################################################

    def to_s
      label #.capitalize
    end

    def all_context_labels
      #meta_key_definitions.collect {|d| "#{d.meta_context}: #{d.meta_field.label}" if d.key_map.blank? }.compact.join(', ')
      meta_definitions.collect {|d| d.label if d.key_map.blank? }.compact.uniq.join(', ')
    end

    ########################################################

    def key_map_for(context)
      context.meta_definitions.find(id).try(:key_map)
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

        mc.meta_definitions.create( :meta_key => mk,
                                    :meta_field => meta_field,
                                    :key_map => key_map,
                                    :key_map_type => nil,
                                    :position => mc.meta_definitions.map(&:position).max + 1 )
      end
      mk
    end

    def self.object_types
      all.collect(&:object_type).uniq.compact.sort
    end

    ###################################################

    # TODO refactor to association has_many :used_meta_terms, :through ...
    def used_term_ids
      meta_data.collect(&:value).flatten.uniq.compact if object_type == "Meta::Term"
    end

    ###################################################
  
    # NOTE config.gem "rgl", :lib => "rgl/adjacency"
    # http://rgl.rubyforge.org/ - http://www.graphviz.org/
    # require 'rgl/adjacency'
    require 'rgl/dot'
    # TODO use ruby-graphviz gem instead ??
    def self.keymapping_graph
        g = RGL::DOT::Digraph.new({ 'name' => 'MAdeK keymapping',
                                    'style' => "filled",
                                    'nodesep' => ".075",
                                    'label' => "Key Mapping Graph\n#{DateTime.now.to_formatted_s(:date_time)}",
                                    'labelloc' => 't',
                                    'labeljust' => 'l',
                                    'ranksep' => "4.0",
                                    'rankdir' => "LR" })
                                  #  node [shape=box,width=.1,height=.1]
  
        ####### Internal cluster
        sg_keys = RGL::DOT::Subgraph.new({ 'name' => "cluster_internal",
                                      'label' => "Internal",
                                      'color' => '#A1D4F1'})
  
          Meta::Key.all.each do |meta_key|
            sg_keys << RGL::DOT::Node.new({'name' => meta_key.label,
                                            'shape' => "box",
                                            'style' => meta_key.is_dynamic? ? "filled" : "",
                                            'width' => "2.7", 'height' => "0" })
          end
    
          ####### for_interface
          Meta::Context.for_interface.each do |context|
            sg = RGL::DOT::Node.new({'name' => context,
                                      'shape' => "box",
                                      'style' => "filled",
                                      'width' => "1.5", 'height' => "1.5" })
            sg_keys << sg
            color = "#"
            3.times { c = rand(8); color << "#{c}"*2 }
            context.meta_definitions.all.each do |definition|
              sg_keys << RGL::DOT::DirectedEdge.new({'from' => definition.meta_key.label,
                                                      'to' => context,
                                                      'arrowhead' => 'none',
                                                      'arrowtail' => 'none',
                                                      'headport' => 'w',
                                                      'tailport' => 'e',
                                                      'color' => color })
            end
          end
        g << sg_keys
        
  
        ####### External cluster
        sg_keys = RGL::DOT::Subgraph.new({ 'name' => "cluster_external",
                                      'label' => "External",
                                      'color' => '#A1D4F1'})
  
          colors = {}
          ####### for_import_export
          Meta::Context.for_import_export.each do |context|
            sg = RGL::DOT::Node.new({ 'name' => context,
                                      'shape' => "box",
                                      'style' => "filled",
                                      'width' => "1.5", 'height' => "1.5" })
            sg_keys << sg
  
            color = "#"
            3.times { c = rand(8); color << "#{c}"*2 }
            colors[context] = color
          end
  
          Meta::Context.all.each do |context|
            context.meta_definitions.where(:key_map.exists => true).each do |definition|
              definition.key_map.split(',').collect do |km|
                km.strip!
    
                sg_keys << RGL::DOT::Node.new({ 'name' => km,
                                                'shape' => "box",
                                                'width' => "3.6", 'height' => "0" })
      
                sg_keys << RGL::DOT::DirectedEdge.new({'from' => context, #working here#10 crashes if many meta_key_definitions are found!!!
                                                        'to' => km,
                                                        'arrowhead' => 'none',
                                                        'arrowtail' => 'none',
                                                        'headport' => 'w',
                                                        'tailport' => 'e',
                                                        #'dir' => 'back',
                                                        'color' => colors[context] })
                sg_keys << RGL::DOT::DirectedEdge.new({'from' => km,
                                                      'to' => definition.meta_key.label,
                                                      'arrowhead' => 'none',
                                                      'arrowtail' => 'none',
                                                      'headport' => 'w',
                                                      'tailport' => 'e',
                                                      #'dir' => 'back',
                                                      'color' => colors[context] })
              end
            end
          end
        g << sg_keys
  
  
        fmt = 'svg' # 'png'
        dotfile = "app/assets/images/graphs/meta"
        src = dotfile + ".dot"
        dot = dotfile + "." + fmt
  
        ::File.open(src, 'w') do |f|
          f << g.to_s << "\n"
        end
        #mongo# system( "#{DOT_PATH} -T#{fmt} #{src} -o #{dot}" ) # dot # neato # twopi # circo # fdp # sfdp 
        system( "dot -T#{fmt} #{src} -o #{dot}" ) # dot # neato # twopi # circo # fdp # sfdp 
        dot.gsub('app/assets/images/', '/assets/')
  
      ############ end graph
    end
    
  end
end
