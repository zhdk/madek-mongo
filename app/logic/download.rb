# -*- encoding : utf-8 -*-

# TODO move to app/models, like upload/import
class Download
  def self.call(env)
      request = Rack::Request.new(env)
      params = request.params
      session = env['rack.session']
      
      current_user = Person.find(session[:user_id]) if session[:user_id]

# e.g.
# 'zip' param present means original file + xml sidecar of meta-data all zipped as one file
# 'update' param present means original file updated by exiftool with current state of madek meta-data for that media_entry
# (update and zip should be treated as mutally exclusive in the context of one download call)
# neither zip nor update present? just give the original file, as it was uploaded.
# WE SHOULD NEVER UPDATE AN UPLOADED FILE WITH MADEK METADATA.

#####################################################################################################################
      not_found = [404, {"Content-Type" => "text/html"}, ["Not found."]]
      return not_found if params['id'].blank?
         
      @media_entry = Media::Entry.accessible_by(current_user.ability, :read).where(:_id => params['id']).first
      return not_found if @media_entry.nil?

      # This is broken, presumably because of ruby 1.8.x not having any native idea of character encodings.
      # If we move the gsub to execute after the unescape has processed, we can easily lose part of the 
      # filename if it contains diacritics and spaces.
      filename = CGI::unescape(@media_entry.media_file.filename.gsub(/\+/, '_'))
      failure = [500, {"Content-Type" => "text/html"}, ["Something went wrong!"]]
      size = params['size'].try(:to_sym)
      
      if size
        preview = @media_entry.media_file.get_preview(size)
        filename = [filename.split('.', 2).first, preview.thumbnail].join('_')
        content_type = preview.content_type
        return [500, {"Content-Type" => "text/html"}, ["Sie haben nicht die notwendige Zugriffsberechtigung."]] unless current_user.ability.can?(:hi_res, @media_entry => Media::Resource) 
      else
        # TODO check permissions for original file ??
        content_type = @media_entry.media_file.content_type
        return [500, {"Content-Type" => "text/html"}, ["Sie haben nicht die notwendige Zugriffsberechtigung."]] unless current_user.ability.can?(:read, @media_entry => Media::Resource) 
      end

#####################################################################################################################
# A media file updated with current madek meta-data, zipped up together with a bunch of side-car meta-data files.
# At present these are yaml and xml files, but they are pretty raw ATM - exposing the internals of the model/schema
# instead of following a well formed and easier to comprehend xml/yml schema..
#####################################################################################################################
      unless params['zip'].blank?
        in_path = @media_entry.updated_resource_file(false, size) # false means we don't want to blank all the tags

        # create the zipfile - we need a name that hopefully won't collide as it's being written to..
        race_free_filename = [Time.now.to_i.to_s, @media_entry.id.to_s, filename].join("_")
        out_path = "#{Media::File::DOWNLOAD_STORAGE_DIR}/#{race_free_filename}.zip"

        Zip::ZipOutputStream.open(out_path) do
          |zos|
          zos.put_next_entry(filename)
          zos.print IO.read(in_path)
          zos.put_next_entry("#{filename}.xml")
          zos.print @media_entry.to_xml(:include => {:meta_data => {:include => :meta_key}}, :except => [:media_file, :permission])
          #mongo# FIXME to_yaml doesn't work
          #mongo# zos.put_next_entry("#{filename}.yml")
          #mongo# zos.print @media_entry.to_yaml(:include => {:meta_data => {:include => :meta_key}}, :except => [:media_file, :permission])
        end

        return out_path ? [200, {"Content-Type" => "application/zip", "Content-Disposition" => "attachment; filename=#{filename}.zip"}, [File.read(out_path)]] : failure

          # TODO - Background job submission to remove the unlocked (ie downloaded) zipfile.
          # since it fails if we try here (because the file is locked while the user 
          # downloads it at some arbitrarily slow speed)
      end

#####################################################################################################################
# An updated file - updated with the current set of madek meta-data
#####################################################################################################################
      unless params['update'].blank?
        path = @media_entry.updated_resource_file(false, size) # false means we don't want to blank all the tags
        return path ? [200, {"Content-Type" => content_type, "Content-Disposition" => "attachment; filename=#{filename}" }, [File.read(path)]] : failure
      end

#####################################################################################################################
# A bare file - as little meta-data as can be allowed without breaking the file.
#####################################################################################################################
      unless params['naked'].blank?
        path = @media_entry.updated_resource_file(true, size) # true means we do want to blank all the tags
        return path ? [200, {"Content-Type" => content_type, "Content-Disposition" => "attachment; filename=#{filename}" }, [File.read(path)]] : failure
      end

      # A transcoded, smaller-than-original version of the video
      if !params['video_thumbnail'].blank? or !params['audio_preview'].blank?
        content_type = if !params['video_thumbnail'].blank?
          "video/webm"
        elsif !params['audio_preview'].blank?
          "audio/ogg"
        end
        preview = @media_entry.media_file.previews.where(:content_type => content_type).last
        if preview.nil?
          return [404, {"Content-Type" => "text/html"}, ["Not found."]]
        else
          path = "#{THUMBNAIL_STORAGE_DIR}/#{@media_entry.media_file.shard}/#{preview.filename}"
          return [200, {"Content-Type" => content_type, "Content-Disposition" => "attachment; filename=#{@media_entry.media_file.filename}" }, [File.read(path) ]]
        end
      end

#####################################################################################################################
# Provide a copy of the original file, not updated or nuffin'
#####################################################################################################################
      path = @media_entry.media_file.file_storage_location
      if size
        outfile = File.join(Media::File::DOWNLOAD_STORAGE_DIR, filename)
        `convert "#{path}" -resize "#{Media::File::THUMBNAILS[size]}" "#{outfile}"`
        path = outfile
      end
      
      # return [200, {"Content-Type" => "text/html"}, [ "#{filename.inspect}" ]] # temp debugging aid
      return [200, {"Content-Type" => content_type, "Content-Disposition" => "attachment; filename=#{filename}" }, [File.read(path) ]]

  end # def 
end # class
