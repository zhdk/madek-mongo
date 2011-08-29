# -*- encoding : utf-8 -*-
module Meta
  class Date # TODO rename to DateTime ??
    include Mongoid::Document

    field :timestamp, type: Integer # TODO enforce to Time or DateTime ??
    field :timezone, type: String
    field :free_text, type: String

    embedded_in :meta_data, class_name: "Meta::Datum"
  
    def to_s
      if parsed
        format = if parsed.to_datetime.seconds_since_midnight > 0 # TODO just .seconds_since_midnight
          :date_time
        else
          :date
        end
        parsed.to_formatted_s(format)
      else
        free_text
      end
    end
  
    def parsed
      Time.at(timestamp) if timestamp
    end
    
  ###################################
    class << self
  
      def parse(string)
        h = {:free_text => string}
        unless string =~ /^[A-Za-z]/ # NOTE we skip the parsing in case of string starting with alphabetic characters
          begin
            #old#
            #      r = if string =~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})[\+|\-](\d{2}):(\d{2})$/ # EXIF standard with time and zone
            #        ::DateTime.strptime(string, DateTime::DATE_FORMATS[:exif_date_time_zone])
            #      elsif string =~ /^(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})$/ # EXIF standard with time
            #        ::DateTime.strptime(string, DateTime::DATE_FORMATS[:exif_date_time])
            #      elsif string =~ /^(\d{4}):(\d{2}):(\d{2})$/ # EXIF standard without time
            #        ::DateTime.strptime(string, Date::DATE_FORMATS[:exif_date])
            #      else
            #        ::DateTime.parse(string)
            #      end
            
            # OPTIMIZE
            if string =~ /^(\d{4}):(\d{2}):(\d{2})/
              string.sub!(':', '-').sub!(':', '-')
            end
            
            date_hash = Date._parse(string)
            unless date_hash.blank?
              h[:timezone] = date_hash[:zone] || Time.zone.formatted_offset        
              h[:timestamp] = Time.parse(string).to_i
            end
          rescue
            # there was no exact match, so we only store the free text
          end
        end
        new(h)
      end
  
      def parse_all
        Meta::Key.where(:object_type => "Meta::Date").each do |key|
          key.meta_data.each do |md|
            md.update_attributes(:value => md.value)
          end
        end
      end
  
    end
    
  end
end