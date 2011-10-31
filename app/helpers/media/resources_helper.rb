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

    ######################################################################

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

    ######################################################################
    
    def display_permission(resource, type = :icon)
      if resource.is_public?
        if type == :icon
          content_tag :div, :class => "icon_status_perm_public" do end
        else
          "(#{_("Öffentlich")})"
        end
      elsif resource.is_private?(current_user)
        if type == :icon
          content_tag :div, :class => "icon_status_perm_private" do end
        else
          "(#{_("Nur für Sie selbst")})"
        end
      else
        # MediaEntries that only I and certain others have access to 
      end
    end

    ######################################################################

    def resource_sizes(resource)
      capture_haml do
        haml_tag :div do
          haml_concat dimensions_for(resource.media_file)
          haml_tag :br
          haml_concat number_to_human_size(resource.media_file.size)
        end
      end
    end

    ######################################################################

    def snapshot_info(media_entry)
      capture_haml do
        haml_tag :div, :class => "notice_tms" do
          date = media_entry.snapshot_media_entry.created_at.to_formatted_s(:date)
          time = media_entry.snapshot_media_entry.created_at.to_formatted_s(:time)
          haml_concat "Eine Kopie dieses Medieneintrages wurde am #{date} um #{time} Uhr für das MIZ-Archiv erstellt."
        end if media_entry.snapshot_media_entry
        haml_tag :div, :class => "notice_tms" do
          haml_concat _("Diese Kopie wird gegenwärtig durch das MIZ-Archiv bearbeitet.")
        end unless media_entry.snapshotable?
      end
    end


  end
end
