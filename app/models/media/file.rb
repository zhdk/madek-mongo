# -*- encoding : utf-8 -*-
module Media
  class File
    include Mongoid::Document

    DIRECTORY = "#{Rails.root}/db/media_files/#{Rails.env}"
    THUMBNAILS = { :x_large => '1024x768>', :large => '620x500>', :medium => '300x300>', :small_125 => '125x125>', :small => '100x100>' }
    # NB This is sharded. A good candidate for a fast filesystem, since thumbnails will be used regularly.
    THUMBNAIL_STORAGE_DIR = "#{DIRECTORY}/thumbnails"
    FILE_STORAGE_DIR = "#{DIRECTORY}/originals"
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
    #field :access_hash ??
    field :thumbnail, type: String # OPTIMIZE only for previews
    field :base64, type: String # OPTIMIZE only for previews

    #tmp# embedded_in :media_entry, class_name: "Media::Entry"
    embedded_in :media_parent, polymorphic: true
    embeds_many :previews, class_name: "Media::File", as: :media_parent
  
    # TODO validates_format_of :content_type, :with => /^image/,

    #########################################################

    # the cornerstone of identity..
    # in an ideal world, this is farmed off to something that can crunch through large files _fast_
    def get_guid
      # This was the old GUID code in use up to June, 2011. Please leave to code here
      # so we know why older files have different GUIDs. The new GUID code doesn't take
      # the file hash into account at all, which is much faster at the expensve of a very
      # low probability of file duplication.
      # We can solve the file duplication problem elsewhere, e.g. by nightly hashing over all files
      # that have identical size and assigning the media entries to the same file if there is a
      # match on the hash. This would be a lot less expensive than doing it during upload.
      #     # TODO in background?
      #     # Hash or object, we should be seeing a pattern here by now.
      #     if uploaded_data.kind_of? Hash
      #       g = Digest::SHA256.hexdigest(uploaded_data[:tempfile].read)
      #       uploaded_data[:tempfile].rewind
      #     else
      #       g = Digest::SHA256.hexdigest(uploaded_data.read)
      #       uploaded_data.rewind
      #     end
      #     g
      return UUIDTools::UUID.random_create.hexdigest
    end

    def shard
      # TODO variable length of sharding?
      self.guid[0..0]
    end
  
    def store_file(file)
      source = file[:tempfile].path #old# ::File.path(file) # uploaded_data[:tempfile].path #tmp# file.tempfile.path

      self.guid = get_guid 
      self.size = ::File.size(source)
      self.filename = file[:filename] #tmp# file.original_filename #tmp# File.basename(file)
      self.content_type = file[:type]

      target = file_storage_location
      FileUtils.copy(source, target)
      return target
    end

    #########################################################

    def get_preview(size = nil)
      unless size.blank?
        #old# p = previews.detect {|x| x.thumbnail == size.to_s}
        p = previews.where(:thumbnail => size).first
        p ||= begin
          #mongo#
          #make_thumbnails([size])
          ##tmp# previews.where(:thumbnail => size.to_s).first
          #previews.detect {|x| x.thumbnail == size.to_s}
          
          # TODO currently only works for image content_type
          image = MiniMagick::Image.open(file_storage_location)
          image.resize THUMBNAILS[size]
          image.format "jpg"
          base64 = Base64.encode64(image.to_blob) #old# Base64.encode64(::File.read(image.path))
          previews.create(:content_type => image.mime_type, :base64 => base64, :height => image[:height], :width => image[:width], :thumbnail => size )
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
        return "data:#{preview.content_type};base64,#{preview.base64}" if preview.base64

        file = ::File.join(THUMBNAIL_STORAGE_DIR, shard, preview.filename)
        if ::File.exist?(file)
          preview.update_attributes(:base64 => Base64.encode64(::File.read(file)))
          return "data:#{preview.content_type};base64,#{preview.base64}"
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
          file = "#{Rails.root}/app/assets/images/#{preview}_#{size}.png"
          base64 = Base64.encode64(::File.read(file))
          return "data:#{content_type};base64,#{base64}"
      end
    end

    # OPTIMIZE
    def meta_data_without_binary
      meta_data ||= {}
      meta_data.reject{|k,v| ["!binary |", "Binary data"].any?{|x| v.to_yaml.include?(x)}}
    end

    #########################################################

    # Video thumbnails only come in one size (large) because re-encoding these costs money and they only make sense
    # in the media_entries/show view anyhow (not in smaller versions).
    def assign_video_thumbnails_to_preview
      content_type = "video/webm"
      if previews.where(:content_type => content_type).empty?
        paths = retrieve_encoded_files
        unless paths.empty?
          paths.each do |path|
            if File.extname(path) == ".webm"
              # Must have Exiftool with Image::ExifTool::Matroska to support WebM!
              w, h = exiftool_obj(path, ["Composite:ImageSize"])[0][0][1].split("x")
              if previews.create(:content_type => content_type, :filename => File.basename(path), :width => w.to_i, :height => h.to_i, :thumbnail => 'large')
                return true
              else
                return false
              end
            end
          end
        end
      end
    end
  
    def assign_audio_previews
      content_type = "audio/ogg"
      if previews.where(:content_type => content_type).empty?
        paths = retrieve_encoded_files
        unless paths.empty?
          paths.each do |path|
            if File.extname(path) == ".ogg"
              if previews.create(:content_type => content_type, :filename => File.basename(path), :width => 0, :height => 0, :thumbnail => 'large')
                return true
              else
                return false
              end
            end
          end
        end
      end
    end

    private

    # The final resting place of the media file. consider it permanent storage.
    # basing the shard on (some non-zero) part of the guid gives us a trivial 'storage balancer' which completely ignores
    # any size attributes of the file, and distributes amongst directories pseudorandomly (which in practice averages out in the long-term).
    def file_storage_location
      # OPTIMIZE
      dir = ::File.join(FILE_STORAGE_DIR, shard)
      ::FileUtils.mkdir_p(dir)
      ::File.join(dir, guid)
    end
  
    def thumbnail_storage_location
      # OPTIMIZE
      dir = ::File.join(THUMBNAIL_STORAGE_DIR, shard)
      ::FileUtils.mkdir_p(dir)
      ::File.join(dir, guid)
    end

    #mongo# TODO remove this method ??
    def make_thumbnails(sizes = nil)
      # this should be a background job
      if content_type.include?('image')
        thumbnail_jpegs_for(file_storage_location, sizes)
      elsif content_type.include?('video')
        # Extracts a cover image from the video stream
        covershot = "#{thumbnail_storage_location}_covershot.png"
        # You can use the -ss option to determine the temporal position in the stream you want to grab from (in seconds)
        conversion = `ffmpeg -i #{file_storage_location} -y -vcodec png -vframes 1 -an -f rawvideo #{covershot}`
        #mongo# TODO get base64 directly
        thumbnail_jpegs_for(covershot, sizes)
        submit_encoding_job
      elsif content_type.include?('audio')
        #add_audio_thumbnails   # This might be a future method that constructs some meaningful thumbnail for an audio file?
        submit_encoding_job
      end
    end

    #mongo# TODO remove this method
    def thumbnail_jpegs_for(file, sizes = nil)
      return unless ::File.exist?(file)
      THUMBNAILS.each do |thumb_size,value|
        next if sizes and !sizes.include?(thumb_size)
        outfile = "#{thumbnail_storage_location}_#{thumb_size.to_s}.jpg"
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

    def retrieve_encoded_files
      require 'lib/encode_job'
      paths = []
      
      unless self.job_id.blank?
        job = EncodeJob.new(self.job_id)
        if job.finished?
          # Get the encoded files via FTP
          job.encoded_file_urls.each do |f|
            filename = File.basename(f)
            prefix = "#{thumbnail_storage_location}_encoded"
            path = "#{prefix}_#{filename}"
            `wget #{f} -O #{path}`
            if $? == 0
              paths << path
            end
          end
        end
      end
      return paths
    end
  
  end
end

