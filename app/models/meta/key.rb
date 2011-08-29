# -*- encoding : utf-8 -*-
module Meta
  class Key
    include Mongoid::Document
    
    key :label
    field :label, type: String
    field :object_type, type: String #mongo# TODO
    field :is_dynamic, type: Boolean #, default: false #mongo# TODO
    field :is_extensible_list, type: Boolean #, default: false #mongo# TODO

    has_and_belongs_to_many :meta_terms, class_name: "Meta::Term", inverse_of: :meta_keys # NOTE need inverse_of
    
    # Mongoid::Errors::MixedRelations: Referencing a(n) Meta::Datum document from the Meta::Key
    # document via a relational association is not allowed since the Meta::Datum is embedded.  
    # has_many :meta_data, :class_name => "Meta::Datum"
    has_many :media_resources, class_name: "Media::Resource", foreign_key: "meta_data.meta_key_id"
    #mongo# OPTIMIZE
    def meta_data
      media_resources.collect(&:meta_data).flatten.select{|md| md.meta_key_id == id}
      #tmp# media_resources.fields(:meta_data => 1).collect(&:meta_data).flatten.select{|md| md.meta_key_id == id}
    end
    
    #tmp#
    def self.count_keywords
      #mongo# TODO this is counting the resources, we want instead the nested total keywords
      #Meta::Key.find("keywords").meta_data.count
      
      #mongo# TODO virtual-collection and index
      #Media::Resource.where(:"meta_data.meta_key_id" => "keywords").fields(:meta_data => 1).collect do |r|
      #  r.meta_data.where(:meta_key_id => "keywords").first.meta_tags.count
      #end.sum

      map = <<-HERECODE
        function() {
          //this.meta_data.filter
          if(this.meta_data && this.meta_data.length){
            this.meta_data.forEach(function(md) {
              if(md.meta_key_id == "keywords" && md.meta_tags)
                //emit("keywords", {size: md.meta_tags.length});
                emit("keywords", md.meta_tags.length);
            });
            //emit(this._id, {cc:this.meta_data.length});
          }
        }
      HERECODE
      
      reduce = <<-HERECODE
        function(key, values) {
          var sum = 0;
          //values.forEach(function(v) { sum += v; });
          //for(var v in values){ sum += values[v].size; }
          for(var v in values){ sum += values[v]; }
          //return {size: sum};
          return sum;
        }
      HERECODE

      #r = Media::Resource.collection.map_reduce(map, reduce, { :out => "keywords_counter"})
      r = Media::Resource.collection.map_reduce(map, reduce, { :query => { :"meta_data.meta_key_id" => "keywords" }, :out => "keywords_counter"})
      r.find().first["value"].to_i 
    end
    
  end
end
