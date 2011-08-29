# -*- encoding : utf-8 -*-
module Meta
  class Reference
    include Mongoid::Document
  
    embedded_in :meta_data, class_name: "Meta::Datum"
    belongs_to :reference, polymorphic: true

    def to_s
      "#{reference}"
    end

  end
end
