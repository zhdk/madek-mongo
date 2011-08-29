# -*- encoding : utf-8 -*-
module Media
  class Set < Resource

    has_and_belongs_to_many :media_resources, class_name: "Media::Resource", inverse_of: :media_sets # NOTE need inverse_of

    #def as_json(options={})
    #  options[:methods] ||= []
    #  options[:methods] << :tag_names
    #  super(options)
    ## super( {:only => ["id", "name", "created_at"]} )
    ## super( {:except => ["id", "name", "created_at"]} )
    ## super(:only => [:email, :name], :include =>[:addresses])
    #end
    def as_json(options={})
      h = { :is_set => true }
      super(options).merge(h)
    end

    def thumb_base64(size = :small)
      # OPTIMIZE permissions
      media_resources.first.try(:thumb_base64, size)
    end

  end
end
