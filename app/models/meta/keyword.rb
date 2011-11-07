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
              if(md._id == "keywords" && md.meta_keywords)
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

      query = { :"meta_data._id" => "keywords" }
      mr = Media::Resource.collection.map_reduce(map, reduce, { :query => query, :out => { :inline => 1}, :raw => true })
      r = mr["results"].first
      r ? r["value"].to_i : 0
    end
    
    def self.used_meta_term_ids
      Media::Resource.all.distinct("meta_data.meta_keywords.meta_term_id") #.map{|id| Meta::Term.find(id).to_s}
    end
    
    def self.group_by_meta_term_id(subject = false)
      #tmp# collection.group(:key => :meta_term_id, :initial => {:count => 0}, :reduce => "function(doc, prev){}")
      k = Media::Resource.all.distinct("meta_data.meta_keywords")
      #k.uniq_by!{|x| x["meta_term_id"]}
      k.keep_if {|h| h["subject_id"].to_s == subject.id } if subject
      k.delete_if {|h| h["created_at"].nil? } # a keyword always has the created_at, a normal term doesn't 
      gk = k.group_by{|x| x["meta_term_id"]}
      keywords = []
      gk.each_value do |v|
        most_recent = v.sort_by {|h| h["created_at"]}.last
        keywords << Meta::Keyword.new(most_recent) do |x|
          x[:q] = v.size
        end
      end
      keywords
    end

  end
end
