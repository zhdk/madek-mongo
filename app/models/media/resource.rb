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

=begin #working here#
    field :data, type: Hash, default: {}
    def set_data(meta_key, new_value)
      return if new_value.nil?
      #data[meta_key.id] = new_value.respond_to?(:id) ? new_value.id : new_value
      data[meta_key.id] = if new_value.is_a? String
        new_value
      elsif new_value.is_a? Array
        new_value.map do |x|
          if x.is_a? Hash
            #keywords
          elsif x.nil?
            #do nothing
          elsif x.respond_to?(:id)
            BSON::DBRef.new(x.collection.name, x.id)
          else
            x
          end
        end
      elsif new_value.respond_to?(:id)
        BSON::DBRef.new(new_value.collection.name, new_value.id)
      end
      puts data.inspect
    end
=end

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
            find_or_initialize_by(:_id => key_id)
          end
        else
          where(:_id.in => context.meta_key_ids)
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

    embeds_one :permission
    Permission::ACTIONS.each do |action|
      index "permission.#{action}.true"
      index "permission.#{action}.false"
    end

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
        :is_favorite => user.favorite_resource_ids.include?(self.id),
        :title => title,
        :author => meta_data.get_value_for("author") }
    end

    #########################################################

    def title
      t = meta_data.get_value_for("title")
      #working here# t = data["title"]
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
      permission.view["true"].include?(:public)
    end 

    def is_private?(user)
      permission.view["true"].size == 1 and permission.view["true"].include?(user.id)
    end

    #mongo# TODO validates presence of the owner's permissions?
    def owner
      Person.where(:_id.in => permission.manage_permissions["true"]).first
    end
    alias :user :owner

    def owner=(user)
      actions = {}
      Permission::ACTIONS.each {|action| actions[action] = true }
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

    #########################################################
    # TODO move to Media::File ??

    # Config files here.
    METADATA_CONFIG_DIR = "#{Rails.root}/config/definitions/metadata"
    # symbolic links, to ultimately break your installation :-/
    # $ sudo ln -s /usr/bin/exiftool /usr/local/bin/exiftool
    # $ sudo ln -s /usr/bin/lib /usr/local/bin/lib
    EXIFTOOL_CONFIG = "#{METADATA_CONFIG_DIR}/ExifTool_config.pl"
    EXIFTOOL_PATH = "exiftool -config #{EXIFTOOL_CONFIG}"

    # Instance method to update a copy (referenced by path) of a media file with the meta_data tags provided
    # args: blank_all_tags = flag indicating whether we clean all the tags from the file, or update the tags in the file
    # returns: the path and filename of the updated copy or nil (if the copy failed)
    def updated_resource_file(blank_all_tags = false, size = nil)
      begin
        if size
          preview = media_file.get_preview(size)
          path = ::File.join(Media::File::DOWNLOAD_STORAGE_DIR, media_file.filename)
          ::File.open(path, 'wb') do |f|
            #f << Base64.decode64(preview.base64)
            f.write(Base64.decode64(preview.base64))
          end
        else
          source_filename = media_file.file_storage_location
          FileUtils.cp( source_filename, Media::File::DOWNLOAD_STORAGE_DIR )
          path = ::File.join(Media::File::DOWNLOAD_STORAGE_DIR, ::File.basename(source_filename))
        end
        # remember we want to handle the following:
        # include all madek tags in file
        # remove all (ok, as many as we can) tags from the file.
        cleaner_tags = (blank_all_tags ? "-All= " : "-IPTC:All= ") + "-XMP-madek:All= -IFD0:Artist= -IFD0:Copyright= -IFD0:Software= " # because we do want to remove IPTC tags, regardless
        tags = cleaner_tags + (blank_all_tags ? "" : to_metadata_tags)
  
        resout = `#{EXIFTOOL_PATH} #{tags} "#{path}"`
        FileUtils.rm("#{path}_original") if resout.include?("1 image files updated") # Exiftool backs up the original before editing. We don't need the backup.
        return path.to_s
      rescue 
        # "No such file or directory" ?
       logger.error "copy failed with #{$!}"
       return nil
      end
    end

    private

    # returns the meta_data for a particular resource, so that it can written into a media file that is to be exported.
    # NB: this is exiftool specific at present, but can be refactored to take account of other tools if necessary.
    # NB: In this case the 'export' in 'get_data_for_export' also means 'download' 
    #     (since we write meta-data to the file anyway regardless of if we do a download or an export)
    def to_metadata_tags
      Meta::Context.io_interface.meta_definitions.collect do |definition|
        # OPTIMIZE
        value = meta_data.get(definition.meta_key_id).value
        
        definition.key_map.split(',').collect do |km|
          km.strip!
          case definition.key_map_type
            when "Array"
              vo = ["-#{km}= "]
              vo += value.collect {|m| "-#{km}='#{(m.respond_to?(:strip) ? m.strip : m)}'" } if value
              vo
            else
              "-#{km}='#{value}'"          
          end
        end
        
      end.join(" ")
    end

    #########################################################

  end
end
