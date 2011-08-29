# -*- encoding : utf-8 -*-
module Media
  class File
    include Mongoid::Document

    DIRECTORY = "#{Rails.root}/db/media_files/#{Rails.env}"
    THUMBNAILS = { :x_large => '1024x768>', :large => '620x500>', :medium => '300x300>', :small_125 => '125x125>', :small => '100x100>' }
    # NB This is sharded. A good candidate for a fast filesystem, since thumbnails will be used regularly.
    THUMBNAIL_STORAGE_DIR = "#{DIRECTORY}/attachments"


    field :guid, type: String
    field :content_type, type: String
    field :filename, type: String
    #mongo# TODO field :meta_data, type: Hash
    field :size, type: Integer
    field :height, type: Integer
    field :width, type: Integer
    field :thumbnail, type: String # OPTIMIZE only for previews
    #`access_hash` ??

    #tmp# embedded_in :media_entry, class_name: "Media::Entry"
    embedded_in :media_parent, polymorphic: true
    embeds_many :previews, class_name: "Media::File", as: :media_parent
  
    # TODO validates_format_of :content_type, :with => /^image/,

    def shard
      # TODO variable length of sharding?
      self.guid[0..0]
    end
  
    def store_file(file)
      #mongo# TODO shard
      dir = ::File.join(DIRECTORY, "original")
      FileUtils.mkdir_p(dir)
      source = file[:tempfile].path #old# ::File.path(file) # uploaded_data[:tempfile].path #tmp# file.tempfile.path

      self.size = ::File.size(source)
      self.filename = file[:filename] #tmp# file.original_filename #tmp# File.basename(file)

      target = ::File.join(dir, filename)
      FileUtils.copy(source, target)
      #mongo# TODO extract_subjective_metadata(target)
      save #mongo# TODO before_create
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
        # get the original
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


  end
end

