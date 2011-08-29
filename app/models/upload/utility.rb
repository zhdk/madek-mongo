# -*- encoding : utf-8 -*-
# Utility functions during upload
module Upload
  class Utility
    def self.detect_type(path)
      file_result = self.type_using_file(path)
      exiftool_result = self.type_using_exiftool(path)
      # If "file" and Exiftool disagree, trust Exiftool
      if [file_result, exiftool_result].compact.uniq.size > 1
        detected_type = exiftool_result
      else
        detected_type = file_result
      end
      
      return detected_type
    end
    
    def self.type_using_file(path)
      return `#{FILE_UTIL_PATH} "#{path}"`.split(";").first.gsub(/\n/,"")
    end
  
    def self.type_using_exiftool(path)
      exif = MiniExiftool.new(path)
      return exif['MIMEType']
    end
  
    def self.assign_type(f)
      # QuickTime containers contain all sorts of messy data, which makes them hard for
      # the 'file' utility to guess, resulting in a lot of application/octet-stream types.
      # But since QuickTime video is always video/quicktime and always .mov, we simply override
      # this based on the filename here.
      # TODO: Could use exiftool instead of 'file' in general, it seems to do a good job with QuickTime
      if f[:filename] =~ /.mov$/
        f[:type] = "video/quicktime"
      else
        supplied_type = f[:type]
        detected_type = detect_type(f[:tempfile].path)
  
        if supplied_type != detected_type
          f[:type] = detected_type
        end
      end
    end
  end
end
