# -*- encoding : utf-8 -*-
module Media
  class Resource
    include Mongoid::Document
    include Mongoid::Timestamps # TODO ?? #include Mongoid::Versioning #max_versions 5
    
    paginates_per 36

    has_and_belongs_to_many :media_sets, class_name: "Media::Set", inverse_of: :media_resources # NOTE need inverse_of

    #field :meta_data, type: Hash, default: {} # {:key_id => :value, ...}
    embeds_many :meta_data, :class_name => "Meta::Datum" do # TODO validates_uniqueness :meta_key
      def get(key_id)
        r = where(:_id => key_id).first # OPTIMIZE prevent find if is_dynamic meta_key
        r ||= build(:_id => key_id)
      end
      def get_value_for(key_id)
        get(key_id).to_s
        #old# get(key_id).try(:value).to_s
      end
      def for_context(context, build_if_not_exists = true)
        if build_if_not_exists
          context.meta_key_ids.collect do |key_id|
            find_or_initialize_by(:meta_key_id => key_id)
          end
        else
          where(:meta_key_id.in => context.meta_key_ids)
        end
      end
    end
    #mongo#
    #accepts_nested_attributes_for :meta_data, :allow_destroy => true,
    #                              :reject_if => proc { |attributes| attributes['value'].blank? and attributes['_destroy'].blank? }
    #                              # NOTE the check on _destroy should be automatic, check Rails > 3.0.3

    #mongo# TODO validates_uniqueness :subject
    embeds_many :permissions
    #field :permissions, type: Hash, default: {} # {:subject_id => [:action_bits, :action_mask], ...}

    #########################################################

    default_scope order_by([[:updated_at, :desc], [:created_at, :desc]])

    #########################################################

    #mongo# TODO index "meta_data.meta_key_id", unique: true

=begin #old#
    include Tire::Model::Search
    include Tire::Model::Callbacks
    index_name 'mongo-resources'
    def to_indexed_json
      #self.to_json(:include => :meta_data)
      self.to_json
    end
#Media::Resource.elasticsearch_index.delete
#Media::Resource.elasticsearch_index.import Media::Resource.all
#Media::Resource.elasticsearch_index.refresh
## s = Media::Resource.search "*"
=end    
  
=begin #old#
    def self.search(query)
      #ok# where(:filename => /testbild_e/)
      #nok# where(:meta_data.exists => query)
      #nok# where("meta_data.values" => /Betty/)
      #Media::Resource.where(:permissions.matches => {:subject_id => self.id, action => true})    
      #where(:meta_data.any => {:value ~=})
    end
=end

    include Mongoid::Search
    search_in :meta_data => :to_s #:value #, { :allow_empty_search => true }

    #########################################################

    def as_json(options={})
      user = options[:user]
      { :id => id,
        :is_private => begin
          #p = permissions.where(:view => true)
          #p.count == 1 and p.where(:subject_id => user.id).count == 1
          p = permissions.select {|x| x.view }
          p.size == 1 and !!p.detect {|x| x.subject_id == user.id } 
        end,
        :is_public => !!permissions.detect {|x| x.subject_id.nil? and x.view },
        :is_editable => !!permissions.detect {|x| x.subject_id == user.id and x.edit },
        :is_manageable => !!permissions.detect {|x| x.subject_id == user.id and x.manage },
        :can_maybe_browse => !meta_data.for_meta_terms.blank?,
        :is_favorite => user.favorite_resources.include?(self),
        :thumb_base64 => thumb_base64(:small_125),
        :title => meta_data.get_value_for("title"),
        :author => meta_data.get_value_for("author") }
    end

    #########################################################

    def title
      t = meta_data.get_value_for("title")
      t = "Ohne Titel" if t.blank?
      t
    end

    def title_and_user
      s = ""
      s += "[Projekt] " if is_a?(Media::Project)
      s += "#{title} (#{user})"
    end
    
    #########################################################

   # OPTIMIZE
    def owner
      #mongo# TODO validates presence of the owner's permissions?
      permissions.where(:manage => true).detect {|x| x.subject.is_a? Person}.try(:subject)
    end
    def user # TODO alias ??
      owner
    end

    def owner=(user)
      h = {:subject => user, :view => true, :edit => true, :manage => true, :hi_res => true}
      permissions.build(h)
    end

    #########################################################

    def default_permission
      permissions.find_or_initialize_by(:subject_id => nil)
    end

=begin
#mongo# TODO prevent generate on seed  
    private
  
    def generate_permissions
      #mongo# TODO Snapshot
      subject = self.user
  
      #mongo# TODO validates presence of the owner's permissions?
      if subject
       user_default_permissions = {:view => true, :edit => true, :manage => true}
       user_default_permissions[:hi_res] = true if self.class == MediaEntry
       permissions.build(:subject => subject).set_actions(user_default_permissions)  
      end # OPTIMIZE
    end
=end


  end
end
