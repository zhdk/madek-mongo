# -*- encoding : utf-8 -*-
module Media
  class Entry < Resource

    embeds_one :media_file, class_name: "Media::File", as: :media_parent #mongo# TODO belongs_to ??
    belongs_to :upload_session, class_name: "Upload::Session"

    ########################################################

    field :is_snapshot, type: Boolean
    # TODO move to super #scope :snapshots, media_entries.where(:is_snapshot => true)

    belongs_to :snapshot_media_entry, class_name: "Media::Entry" # TODO has_one ??

    def to_snapshot
      if snapshotable?
        snapshot_media_entry.try(:delete) # OPTIMIZE
        
        self.snapshot_media_entry = Media::Entry.create(:meta_data => meta_data.clone, :media_file => media_file.clone) do |x| 
          subject = Group.where(:name => "MIZ-Archiv").first
          actions = {:view => true, :edit => true, :hi_res => true, :manage_permissions => true}
          x.build_permission unless x.permission # TODO merge with after_initialize
          actions.each_pair do |action, boolean|
            x.permission.send((boolean.to_s == "true" ? :grant : :deny), {action => subject}) 
          end
          # TODO push to Snapshot group ??
          x.is_snapshot = true
        end

        save
                
        # OPTIMIZE
        descr_author = snapshot_media_entry.meta_data.get("description author")
        if descr_author.meta_key
          descr_author_value = descr_author.value
          snapshot_media_entry.meta_data.get("description author before snapshot").update_attributes(:value => descr_author_value) if descr_author_value
        end
      end
    end
  
    # return true if there is no snapshot already
    # or if there is the snapshot is not edited yet
    def snapshotable?
      snapshot_media_entry.nil? or not snapshot_media_entry.edited?
    end

    ########################################################

    def as_json(options={})
      h = { :is_set => false,
            :thumb_base64 => media_file.try(:thumb_base64, :small_125) }
      super(options).merge(h)
    end

    ########################################################
    
    # OPTIMIZE
    def individual_contexts
      media_sets.collect {|project| project.individual_contexts }.flatten.uniq
    end

    ########################################################
    #
    before_create :process_file #mongo# TODO ?? :set_copyright
    
    private
    
    def process_file
      if (file = attributes.delete("file"))
        media_file = build_media_file
        target = media_file.store_file(file)
        extract_subjective_metadata(target)
      end
    end

    def extract_subjective_metadata(file_path)
      group_tags = ['XMP-madek', 'XMP-dc', 'XMP-photoshop', 'XMP-iptcCore', 'XMP-xmpRights', 'XMP-expressionmedia', 'XMP-mediapro']
      ignore_fields = [/^XMP-photoshop:ICCProfileName$/,/^XMP-photoshop:LegacyIPTCDigest$/, /^XMP-expressionmedia:(?!UserFields)/, /^XMP-mediapro:(?!UserFields)/]
      
      blob = []
      parse_hash = JSON.parse(`#{EXIFTOOL_PATH} -s "#{file_path}" -a -u -G1 -D -j`).first
      group_tags.each do |tag_group|
        blob << parse_hash.select {|k,v| k.include?(tag_group)}.sort
      end

      process_metadata_blob(blob, ignore_fields)
    end

    def process_metadata_blob(blob, ignore_fields = [])
      blob.each do |tag_array_entry|
        tag_array_entry.each do |entry|
          entry_key = entry[0]
          entry_value = entry[1]
          next if ignore_fields.detect {|e| entry_key =~ e}
  
          if entry_key =~ /^XMP-(expressionmedia|mediapro):UserFields/
            Array(entry_value).each do |s|
              entry_key, entry_value = s.split('=', 2)
  
              # TODO priority ??
              case entry_key
                when "Datum", "Datierung"
                  meta_key = MetaKey.find_by_label("portrayed object dates")
                when "Autor/in"
                  meta_key = MetaKey.find_by_label("author")
                else
                  next
              end
  
              # TODO dry
              next if entry_value.blank? or entry_value == "-" #mongo# or meta_data.detect {|md| md.meta_key == meta_key } # we do sometimes receive a blank value in metadata, hence the check.
              entry_value.gsub!(/\\n/,"\n") if entry_value.is_a?(String) # OPTIMIZE line breaks in text are broken somehow
              set_data(meta_key, entry_value)
            end
          else
            meta_key = Meta::Key.meta_key_for(entry_key) #10 TODO ?? , Meta::Context.file_embedded)

            next if entry_value.blank? #mongo# or meta_data.detect {|md| md.meta_key == meta_key } # we do sometimes receive a blank value in metadata, hence the check.
            entry_value.gsub!(/\\n/,"\n") if entry_value.is_a?(String) # OPTIMIZE line breaks in text are broken somehow
            set_data(meta_key, entry_value)
          end
  
        end
      end
    end
    #
    ########################################################

=begin 
    # see mapping table on http://code.zhdk.ch/projects/madek/wiki/Copyright
    def set_copyright
      copyright_status = meta_data.detect {|md| ["copyright status"].include?(md.meta_key.label) }
      are_usage_or_url_defined = meta_data.detect {|md| ["copyright usage", "copyright url"].include?(md.meta_key.label) }
      klass = Meta::Copyright
  
      if !copyright_status
        value = (are_usage_or_url_defined ? klass.custom : klass.default)
        meta_data.build(:meta_key => Meta::Key.where(:label => "copyright status").first, :value => value)
      elsif copyright_status.value.class == TrueClass or are_usage_or_url_defined 
        copyright_status.value = klass.custom
      elsif copyright_status.value.class == FalseClass
        copyright_status.value = klass.public
      else
        copyright_status.value = klass.default
      end
    end
=end

    ########################################################

    def self.compare_batch_by_meta_data_in_context(media_entries, context)
      compared_against, other_entries = media_entries[0], media_entries[1..-1]
      meta_data_for_context = compared_against.meta_data.for_context(context)

      new_blank_media_entry = self.new
      meta_data_for_context.each do |md_bare|
        if other_entries.any? {|me| not me.meta_data.get(md_bare[:_id]).same_value?(md_bare[:value])}
          new_blank_media_entry.meta_data.build(:_id => md_bare[:_id], :value => nil, :keep_original_value => true)
        else
          new_blank_media_entry.meta_data.build(:_id => md_bare[:_id], :value => md_bare[:value])
        end
      end
      new_blank_media_entry
    end

    ########################################################

  end
end
