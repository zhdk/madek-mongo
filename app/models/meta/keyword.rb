# -*- encoding : utf-8 -*-
module Meta
  class Keyword
    include Mongoid::Document
    include Mongoid::Timestamps::Created
  
    embedded_in :meta_data, class_name: "Meta::Datum"
    belongs_to :meta_term, class_name: "Meta::Term"
    belongs_to :subject, class_name: "Subject" #mongo# TODO Person instead ??

    def to_s
      "#{meta_term}"
    end

    ###############################################################
    
    # overriding aggregation count method, that wasn't working in any case because embedded 
    def self.count
      map = <<-HERECODE
        function() {
          if(this.meta_data && this.meta_data.length){
            this.meta_data.forEach(function(md) {
              if(md.meta_key_id == "keywords" && md.meta_keywords)
                emit("keywords", md.meta_keywords.length);
            });
          }
        }
      HERECODE
      
      reduce = <<-HERECODE
        function(key, values) {
          var sum = 0;
          for(var v in values){ sum += values[v]; }
          return sum;
        }
      HERECODE

      query = { :"meta_data.meta_key_id" => "keywords" }
      mr = Media::Resource.collection.map_reduce(map, reduce, { :query => query, :out => { :inline => 1}, :raw => true })
      r = mr["results"].first
      r ? r["value"].to_i : 0
    end

  end
end
