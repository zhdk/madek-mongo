# -*- encoding : utf-8 -*-
module Media
  class Entry < Resource

    embeds_one :media_file, class_name: "Media::File", as: :media_parent #mongo# TODO belongs_to ??
    belongs_to :upload_session, class_name: "Upload::Session"

    ###############################

    def as_json(options={})
      h = { :is_set => false }
      super(options).merge(h)
    end

    def thumb_base64(size = :small)
      media_file.try(:thumb_base64, size)
    end

    ###############################
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
      #mongo# parse_hash = JSON.parse(`#{EXIFTOOL_PATH} -s "#{file_path}" -a -u -G1 -D -j`).first
      parse_hash = JSON.parse(`exiftool -s "#{file_path}" -a -u -G1 -D -j`).first
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
              meta_data.create(:meta_key => meta_key, :value => entry_value )
            end
          else
            meta_key = Meta::Key.meta_key_for(entry_key) #10 TODO ?? , Meta::Context.file_embedded)

            next if entry_value.blank? #mongo# or meta_data.detect {|md| md.meta_key == meta_key } # we do sometimes receive a blank value in metadata, hence the check.
            entry_value.gsub!(/\\n/,"\n") if entry_value.is_a?(String) # OPTIMIZE line breaks in text are broken somehow
            meta_data.create(:meta_key => meta_key, :value => entry_value )
          end
  
        end
      end
    end
    #
    ###############################

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

  end
end
