# -*- encoding : utf-8 -*-
module Media
  class Entry < Resource

    embeds_one :media_file, class_name: "Media::File", as: :media_parent #mongo# TODO belongs_to ??
    belongs_to :upload_session, class_name: "Upload::Session"

    def as_json(options={})
      h = { :is_set => false,
            :is_favorite => true }
      super(options).merge(h)
    end

    def thumb_base64(size = :small)
      media_file.try(:thumb_base64, size)
    end

    ###############################
    #
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
              meta_data.build(:meta_key => meta_key, :value => entry_value )
            end
          else
            #mongo# meta_key = MetaKey.meta_key_for(entry_key) #working here#10 , MetaContext.file_embedded)
            meta_key = entry_key 

            next if entry_value.blank? #mongo# or meta_data.detect {|md| md.meta_key == meta_key } # we do sometimes receive a blank value in metadata, hence the check.
            entry_value.gsub!(/\\n/,"\n") if entry_value.is_a?(String) # OPTIMIZE line breaks in text are broken somehow
            meta_data.build(:meta_key => meta_key, :value => entry_value )
          end
  
        end
      end
    end
    #
    ###############################

  end
end
