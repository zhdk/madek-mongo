# -*- encoding : utf-8 -*-
module Media
  class Resource
    include Mongoid::Document
    include Mongoid::Timestamps # TODO ?? #include Mongoid::Versioning #max_versions 5

    #########################################################
    
    include Mongoid::Search
    search_in :meta_data => :to_s #:value #, { :allow_empty_search => true }

    #########################################################
    
    paginates_per 36

    #########################################################

    has_and_belongs_to_many :media_sets, class_name: "Media::Set", inverse_of: :media_resources # NOTE need inverse_of

    #mongo# TODO ?? index "meta_data.meta_key_id", unique: true
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
    #accepts_nested_attributes_for :meta_data, :allow_destroy => true #,
                                  #mongo# :reject_if => proc { |attributes| attributes['value'].blank? and attributes['_destroy'].blank? }
                                  # NOTE the check on _destroy should be automatic, check Rails > 3.0.3
    # NOTE alternative to accepts_nested_attributes_for
    def meta_data_attributes=(attributes)
      attributes.values.each do |h|
        next if h[:id].blank? and h[:value].blank?
        if (id = h.delete(:id))
          #old# meta_data.find(id).update_attributes(h)
          # OPTIMIZE
          md = meta_data.where(:_id => id).first
          md.attributes = h if md
        else
          meta_data.build(h)
        end
      end
    end    


    #mongo# TODO validates_uniqueness :subject
    embeds_many :permissions
    #field :permissions, type: Hash, default: {} # {:subject_id => [:action_bits, :action_mask], ...}

    #########################################################

    default_scope order_by([[:updated_at, :desc], [:created_at, :desc]])

    #########################################################

=begin
    def update_attributes_with_pre_validation(new_attributes, current_user = nil)
      # we need to deep copy the attributes for batch edit (multiple resources)
      dup_attributes = Marshal.load(Marshal.dump(new_attributes))

      # To avoid overriding at batch update: remove from attribute hash if :keep_original_value and value is blank
      dup_attributes[:meta_data_attributes].delete_if { |key, attr| attr[:keep_original_value] and attr[:value].blank? }

      dup_attributes[:meta_data_attributes].each_pair do |key, attr|
        if attr[:value].is_a? Array and attr[:value].all? {|x| x.blank? }
          attr[:value] = nil
        end

        # find existing meta_datum, if it exists
        if attr[:id].blank? and (md = meta_data.where(:meta_key_id => attr[:meta_key_id]).first)
          attr[:id] = md.id
        end

        # get rid of meta_datum if value is blank
        if !attr[:id].blank? and attr[:value].blank?
          attr[:_destroy] = true
          #old# attr[:value] = "." # NOTE bypass the validation
        end
      end if dup_attributes[:meta_data_attributes]

      #mongo# self.editors << current_user if current_user # OPTIMIZE group by user ??
      #mongo# still needed ?? or move to before_save or before_update ??
      self.updated_at = Time.now # used for cache invalidation and sphinx reindex # OPTIMIZE touch or sphinx_touch ??

      update_attributes_without_pre_validation(dup_attributes)
    end
    alias_method_chain :update_attributes, :pre_validation
=end
    #########################################################

    def as_json(options={})
      user = options[:user]
      ability = options[:ability]
      { :id => id,
        :is_public => is_public?,
        :is_private => is_private?(user),
        :is_editable => ability.can?(:update, self => Media::Resource),
        :is_manageable => ability.can?(:manage, self => Media::Resource),
        :can_maybe_browse => !meta_data.for_meta_terms.blank?,
        :is_favorite => user.favorite_resources.include?(self),
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

    def is_public?
      !!permissions.detect {|x| x.subject_id.nil? and x.view }
    end 

    def is_private?(user)
      #p = permissions.where(:view => true)
      #p.count == 1 and p.where(:subject_id => user.id).count == 1
      p = permissions.select {|x| x.view }
      p.size == 1 and !!p.detect {|x| x.subject_id == user.id } 
    end

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
