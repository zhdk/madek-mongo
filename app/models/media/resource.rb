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

    #########################################################

    #working here#
    # index "meta_data.meta_key_id" # TODO , unique: true
    index "meta_data._id" # TODO , unique: true

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
    accepts_nested_attributes_for :meta_data, :allow_destroy => true,
                                              :reject_if => proc { |attributes| attributes['value'].blank? }
                                  #mongo# :reject_if => proc { |attributes| attributes['value'].blank? and attributes['_destroy'].blank? }
                                  # NOTE the check on _destroy should be automatic, check Rails > 3.0.3
=begin
    # NOTE alternative to accepts_nested_attributes_for
    def meta_data_attributes=(attributes)
      attributes.values.each do |h|
        next if h[:id].blank? and h[:value].blank?
        if (id = h.delete(:id))
          #old# meta_data.find(id).update_attributes(h)
          # OPTIMIZE
          md = meta_data.where(:_id => id).first
          if md
            if h[:value].blank?
              md.delete
            else
              md.attributes = h
            end
          end
        else
          meta_data.build(h)
        end
      end
    end    
=end

    #########################################################

    #old# field :permissions, type: Hash, default: {} # {:subject_id => [:action_bits, :action_mask], ...}
    embeds_one :permission
    # TODO index "permission. ..."

    validates_presence_of :permission
    after_initialize do
      build_permission unless permission
    end

    #########################################################

    embeds_many  :edit_sessions #, :readonly => true #, :limit => 5
    #has_many  :editors, :through => :edit_sessions, :source => :user do
    #  def latest
    #    first
    #  end
    #end

    def edited?
      not edit_sessions.empty?
    end

    #########################################################

    default_scope order_by([[:updated_at, :desc], [:created_at, :desc]])

    #########################################################

    def update_attributes_with_pre_validation(new_attributes, current_user = nil)
=begin
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
=end

      #mongo# self.editors << current_user if current_user # OPTIMIZE group by user ??
      edit_sessions.create(:subject => current_user) if current_user

      #mongo# still needed ?? or move to before_save or before_update ??
      #self.updated_at = Time.now # used for cache invalidation and sphinx reindex # OPTIMIZE touch or sphinx_touch ??

      #update_attributes_without_pre_validation(dup_attributes)
      update_attributes_without_pre_validation(new_attributes)
    end
    alias_method_chain :update_attributes, :pre_validation
    #########################################################

    def as_json(options={})
      user = options[:user]
      ability = options[:ability]
      { :id => id,
        :is_public => is_public?,
        :is_private => is_private?(user),
        :is_editable => ability.can?(:update, self => Media::Resource),
        :is_manageable => ability.can?(:manage_permissions, self => Media::Resource),
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
      #tmp# permission.view["true"].include?(:public)
      permission.attributes["public"].try(:include?, :view)
    end 

    def is_private?(user)
      #tmp# permission.view["true"].size == 1 and permission.view["true"].include?(user.id)
      permission.subject_ids.size == 1 and permission.attributes[user.id].try(:include?, :view) 
    end

    #mongo# TODO validates presence of the owner's permissions?
    def owner
      #tmp# Person.where(:_id.in => permission.manage_permissions["true"]).first
      Person.where(:_id.in => permission.subject_ids).first
    end
    def user # TODO alias ??
      owner
    end

    def owner=(user)
      actions = {:view => true, :edit => true, :manage_permissions => true, :hi_res => true}
      actions.each_pair do |action, boolean|
        permission.send((boolean.to_s == "true" ? :grant : :deny), {action => user}) 
      end
    end

    #########################################################

    def default_permission=(actions)
      actions.each_pair do |action, boolean|
        permission.send((boolean.to_s == "true" ? :grant : :deny), {action => :public}) 
      end
    end

  end
end
