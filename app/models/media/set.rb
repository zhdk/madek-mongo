# -*- encoding : utf-8 -*-
module Media
  class Set < Resource

    has_and_belongs_to_many :media_resources, class_name: "Media::Resource", inverse_of: :media_sets # NOTE need inverse_of
    has_and_belongs_to_many :individual_contexts, class_name: "Meta::Context", inverse_of: :media_sets # NOTE need inverse_of

    ########################################################

    field :is_featured, type: Boolean

    scope :featured, where(:is_featured => true).limit(1)

    ########################################################

    def to_s
      #mongo#
      #s = "#{title} " 
      #s += "- %s " % self.class.name.split('::').last # OPTIMIZE get class name without module name
      #s += (static? ? "(#{media_entries.count})" : "(#{MediaEntry.search_count(query, :match_mode => :extended2)}) [#{query}]")
      if is_featured
        "Beispielhafte Sets"
      else
        title
      end
    end

    ########################################################

    #def as_json(options={})
    #  options[:methods] ||= []
    #  options[:methods] << :tag_names
    #  super(options)
    ## super( {:only => ["id", "name", "created_at"]} )
    ## super( {:except => ["id", "name", "created_at"]} )
    ## super(:only => [:email, :name], :include =>[:addresses])
    #end
    def as_json(options={})
      ability = options[:ability]
      h = { :is_set => true,
            :thumb_base64 => main_media_resource(ability).try(:media_file).try(:thumb_base64, :small_125) }
      super(options).merge(h)
    end

    # OPTIMIZE
    def main_media_resource(ability)
      media_resources.accessible_by(ability).first
    end

    ########################################################
=begin
#mongo# 
    # TODO scope accessible media_entries only
    def abstract(min_media_entries = nil, accessible_media_entry_ids = nil)
      min_media_entries ||= media_entries.count.to_f * 50 / 100
      accessible_media_entry_ids ||= media_entry_ids
      meta_key_ids = individual_contexts.map(&:meta_key_ids).flatten
      h = {} #1005# TODO upgrade to Ruby 1.9 and use ActiveSupport::OrderedHash.new
      mds = MetaDatum.where(:meta_key_id => meta_key_ids, :resource_type => "MediaEntry", :resource_id => accessible_media_entry_ids)
      mds.each do |md|
        h[md.meta_key_id] ||= [] # TODO md.meta_key
        h[md.meta_key_id] << md.value
      end
      h.delete_if {|k, v| v.size < min_media_entries }
      h.each_pair {|k, v| h[k] = v.flatten.group_by {|x| x}.delete_if {|k, v| v.size < min_media_entries }.keys }
      h.delete_if {|k, v| v.blank? }
      #1005# return h.collect {|k, v| meta_data.build(:meta_key_id => k, :value => v) }
      b = []
      h.each_pair {|k, v| b[meta_key_ids.index(k)] = meta_data.build(:meta_key_id => k, :value => v) }
      return b.compact
    end
  
    def used_meta_term_ids(accessible_media_entry_ids = nil)
      accessible_media_entry_ids ||= media_entry_ids
      meta_key_ids = individual_contexts.map{|ic| ic.meta_keys.for_meta_terms.map(&:id) }.flatten
      mds = MetaDatum.where(:meta_key_id => meta_key_ids, :resource_type => "MediaEntry", :resource_id => accessible_media_entry_ids)
      mds.collect(&:value).flatten.uniq.compact
    end
=end

    ########################################################
    
    # OPTIMIZE get rid of this method
    def self.find_by_id_or_create_by_title(values, user)
      records = Array(values).map do |v|
                        a = where(:_id => v).first
                        a ||= begin
                          mk = Meta::Key.where(:label => "title").first
                          #mongo# TODO user.media_sets.create(:meta_data_attributes => [{:meta_key_id => mk.id, :value => v}])
                          ms = Media::Set.create do |x|
                            x.owner = user
                          end
                          ms.meta_data.create(:meta_key_id => mk.id, :value => v)
                          ms
                        end
                    end
      records.compact
    end


  end
end
