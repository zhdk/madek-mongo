# -*- encoding : utf-8 -*-
module Meta
  class Tag
    include Mongoid::Document
    include Mongoid::Timestamps::Created
  
    embedded_in :meta_data, class_name: "Meta::Datum"
    belongs_to :meta_term, class_name: "Meta::Term"
    belongs_to :subject, class_name: "Subject" #mongo# TODO Person instead ??

    def to_s
      "#{meta_term}"
    end

  end
end
