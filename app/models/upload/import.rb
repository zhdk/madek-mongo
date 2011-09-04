# -*- encoding : utf-8 -*-
module Upload
  class Import
    def self.call(env)
        request = Rack::Request.new(env)
        params = request.params
        session = env['rack.session']
  
        current_user = Person.find(session[:user_id]) if session[:user_id]
        
        files = if !params['uploaded_data'].blank?
          params['uploaded_data']
        elsif !params['import_path'].blank?
          Dir[File.join(params['import_path'], '**', '*')]
        else
          nil
        end
  
        unless files.blank?
          # OPTIMIZE append if already exists (multiple grouped posts)
          #temp# upload_session = current_user.upload_sessions.latest
          upload_session = current_user.upload_sessions.create
  
          files.each do |f|
            # Mac OS X sometimes lies about the content type, so we have to detect the supplied type
            # separately from the true type
            uploaded_data = if params['uploaded_data']
              Upload::Utility.assign_type(f)
              f
            else
              { :type=> Upload::Utility.detect_type(f),
                :tempfile=> File.new(f, "r"),
                :filename=> File.basename(f)}
            end
  
            # if uploaded_data['filename'].include?
            # uploaded_data['current_user'] = current_user.login # for the use of media_file, if we get a zipfile

            media_entry = upload_session.media_entries.create(:file => uploaded_data)
            
            #mongo#0409# TODO move to Media::Entry#generate_permissions ?? or just delegate to upload_controller#set_permissions ??
            h = {:subject => current_user, :view => true, :edit => true, :manage => true, :hi_res => true}
            media_entry.permissions.create(h)

            # If this is a path-based upload for e.g. video files, it's almost impossible that we've imported the title
            # correctly because some file formats don't give us that metadata. Let's overwrite with an auto-import default then.
            # TODO: We should get this information from a YAML file that's uploaded with the media file itself instead.
            unless params['uploaded_data']
              # TODO: Extract metadata from separate YAML file here, along with refactoring MediaEntry#process_metadata_blob and friends
              mandatory_key_ids = Meta::Key.where(:label => ['title', 'copyright notice']).collect(&:id)
              if media_entry.meta_data.where(:meta_key_id => mandatory_key_ids).empty?
                mandatory_key_ids.each do |key_id|
                  media_entry.meta_data.create(:meta_key_id => key_id, :value => 'Auto-created default during import')
                end
              end
            end
  
            uploaded_data[:tempfile].close unless params['uploaded_data']
          end
        end
  
        # TODO check if all media_entries successfully saved
  
        if params['xhr']
          [200, {"Content-Type" => "text/html"}, [""]]
        else
          uri = if params['uploaded_data']
                  "/upload"
                elsif params['import_path']
                  "/upload/import_summary"
                else
                  "/upload/new"
                end
          [ 303, {'Content-Length'=>'0', 'Content-Type'=>'text/plain', 'Location' => uri}, []]
        end
    end

  end
end
