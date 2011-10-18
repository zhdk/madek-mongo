# -*- encoding : utf-8 -*-
module Media
  module ResourcesHelper

    def thumb_for(resource, size = :small_125, options = {})
      media_file = if resource.is_a?(Media::Set)
        resource.main_media_resource(current_ability).try(:media_file)
      else
        resource.media_file
      end
      return "" unless media_file
      
      # Give a video preview if there is one, otherwise revert to a preview
      # image that was extracted from the video file.
      if media_file.content_type =~ /video/ && size == :large
        media_file.assign_video_thumbnails_to_preview
        video_preview = media_file.previews.where(:content_type => 'video/webm', :thumbnail => 'large').last
        if video_preview.nil?
          tag :img, options.merge({:src => media_file.thumb_base64(size)})
        else
          tag :video,  options.merge({:src => "/download?id=#{resource.id}&video_thumbnail=true",
                                      :autoplay => 'autoplay', :controls => 'controls', :width => video_preview.width, :height => video_preview.height})
        end
  
      elsif media_file.content_type =~ /audio/ && size == :large
        media_file.assign_audio_previews
        tag :audio,  options.merge({:src => "/download?id=#{resource.id}&audio_preview=true",
                                    :autoplay => 'autoplay', :controls => 'controls'})
      else
        tag :img, options.merge({:src => media_file.thumb_base64(size)})
      end
    end

    def select_dimensions_header_for_entry(entry)
      media_file = entry.media_file
      unless media_file.nil?
        case media_file.content_type
          when /audio/ then
            header = "Dauer"
          # when /video/ then
          #   
          # when /image/ then
          else
            header = "Dimensionen (Format)"
        end
      end
      return header
    end

    def file_format_for(media_file)
      case media_file.content_type
        when /image/ then
          format = media_file.content_type.gsub(/image\//, '')
        # other media formats ....
      else
        media_file.content_type
      end
    end

  end
end
