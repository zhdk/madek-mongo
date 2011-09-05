# -*- encoding : utf-8 -*-
module Media
  class File
    include Mongoid::Document

    DIRECTORY = "#{Rails.root}/db/media_files/#{Rails.env}"
    THUMBNAILS = { :x_large => '1024x768>', :large => '620x500>', :medium => '300x300>', :small_125 => '125x125>', :small => '100x100>' }
    # NB This is sharded. A good candidate for a fast filesystem, since thumbnails will be used regularly.
    THUMBNAIL_STORAGE_DIR = "#{DIRECTORY}/attachments"
    FILE_STORAGE_DIR = "#{DIRECTORY}/original"
    # OPTIMIZE
    FileUtils.mkdir_p(THUMBNAIL_STORAGE_DIR)
    FileUtils.mkdir_p(FILE_STORAGE_DIR)


    field :guid, type: String
    field :content_type, type: String
    field :filename, type: String
    field :meta_data, type: Hash #, default: {} #mongo# TODO 
    field :size, type: Integer
    field :height, type: Integer
    field :width, type: Integer
    field :thumbnail, type: String # OPTIMIZE only for previews
    #`access_hash` ??

    #tmp# embedded_in :media_entry, class_name: "Media::Entry"
    embedded_in :media_parent, polymorphic: true
    embeds_many :previews, class_name: "Media::File", as: :media_parent
  
    # TODO validates_format_of :content_type, :with => /^image/,

    #########################################################

    def shard
      # TODO variable length of sharding?
      #mongo# TODO self.guid[0..0]
      ""
    end
  
    def store_file(file)
      #mongo# TODO shard
      source = file[:tempfile].path #old# ::File.path(file) # uploaded_data[:tempfile].path #tmp# file.tempfile.path

      self.size = ::File.size(source)
      self.filename = file[:filename] #tmp# file.original_filename #tmp# File.basename(file)
      self.content_type = file[:type]

      target = file_storage_location
      FileUtils.copy(source, target)
      return target
    end

    def get_preview(size = nil)
      unless size.blank?
        #tmp# p = previews.where(:thumbnail => size.to_s).first
        p = previews.detect {|x| x.thumbnail == size.to_s}
        p ||= begin
          make_thumbnails([size])
          #tmp# previews.where(:thumbnail => size.to_s).first
          previews.detect {|x| x.thumbnail == size.to_s}
        end
        # OPTIMIZE p could still be nil !!
        return p
      else
        # get the original # TODO check permissions
        return file_storage_location
      end
    end

    def thumb_base64(size = :small)
      # TODO give access to the original one?
      # available_sizes = THUMBNAILS.keys #old# ['small', 'medium']
      # size = 'small' unless available_sizes.include?(size)

      preview = case content_type
                  when /video/ then
                    # Get the video's covershot that we've extracted/thumbnailed on import
                    get_preview(size) || "Video"
                  when /audio/ then
                    "Audio"
                  when /image/ then
                    get_preview(size) || "Image"
                  else 
                    "Doc"
                end
  
      # OPTIMIZE
      unless preview.is_a? String
        file = ::File.join(THUMBNAIL_STORAGE_DIR, shard, preview.filename)
        if ::File.exist?(file)
         output = ::File.read(file)
         return "data:#{preview.content_type};base64,#{Base64.encode64(output)}"
        else
          preview = "Image" # OPTIMIZE
        end
      end
  
      # nothing found, we show then a placeholder icon
      case Rails.env
        when false #tmp# "development"
          w, h = THUMBNAILS[size].split('x').map(&:to_i)
          categories = %w(abstract food people technics animals nightlife nature transport city fashion sports)
          i = id.to_a.sum
          cat = categories[i % categories.size]
          n = (i % 10) + 1
          return "http://lorempixum.com/#{w}/#{h}/#{cat}/#{n}"
        else
          size = (size == :large ? :medium : :small)
          output = ::File.read("#{Rails.root}/app/assets/images/#{preview}_#{size}.png")
          return "data:#{content_type};base64,#{Base64.encode64(output)}"
      end
    end

    # OPTIMIZE
    def meta_data_without_binary
      meta_data ||= {}
      meta_data.reject{|k,v| ["!binary |", "Binary data"].any?{|x| v.to_yaml.include?(x)}}
    end

    #########################################################

    private

    # The final resting place of the media file. consider it permanent storage.
    # basing the shard on (some non-zero) part of the guid gives us a trivial 'storage balancer' which completely ignores
    # any size attributes of the file, and distributes amongst directories pseudorandomly (which in practice averages out in the long-term).
    def file_storage_location
      #mongo# ::File.join(FILE_STORAGE_DIR, shard, guid)
      ::File.join(FILE_STORAGE_DIR, filename)
    end
  
    def thumbnail_storage_location
      #mongo# ::File.join(THUMBNAIL_STORAGE_DIR, shard, guid)
      ::File.join(THUMBNAIL_STORAGE_DIR, filename)
    end

    def make_thumbnails(sizes = nil)
      # this should be a background job
      if content_type.include?('image')
        thumbnail_jpegs_for(file_storage_location, sizes)
      elsif content_type.include?('video')
        # Extracts a cover image from the video stream
        covershot = "#{thumbnail_storage_location}_covershot.png"
        # You can use the -ss option to determine the temporal position in the stream you want to grab from (in seconds)
        conversion = `ffmpeg -i #{file_storage_location} -y -vcodec png -vframes 1 -an -f rawvideo #{covershot}`
        thumbnail_jpegs_for(covershot, sizes)
        submit_encoding_job
      elsif content_type.include?('audio')
        #add_audio_thumbnails   # This might be a future method that constructs some meaningful thumbnail for an audio file?
        submit_encoding_job
      end
    end

    def thumbnail_jpegs_for(file, sizes = nil)
      return unless ::File.exist?(file)
      THUMBNAILS.each do |thumb_size,value|
        next if sizes and !sizes.include?(thumb_size)
        tmparr = "#{thumbnail_storage_location}_#{thumb_size.to_s}"
        outfile = [tmparr, 'jpg'].join('.')
        `convert -verbose "#{file}" -auto-orient -thumbnail "#{value}" -flatten -unsharp 0x.5 "#{outfile}"`
        if ::File.exists?(outfile)
          x,y = `identify -format "%wx%h" "#{outfile}"`.split('x')
          if x and y
            previews.create(:content_type => 'image/jpeg', :filename => outfile.split('/').last, :height => y, :width => x, :thumbnail => thumb_size.to_s )
          end
        else
          # if convert failed, we need to take or delegate off some rescue action, ideally.
          # but for the moment, lets just imply no-thumbnail need be made for this size
        end
      end
    end

  end
end

