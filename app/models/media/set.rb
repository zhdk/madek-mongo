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


    ########################################################
    
    # OPTIMIZE get rid of this method
    def self.find_by_id_or_create_by_title(values, user)
      records = Array(values).map do |v|
                        a = where(:id => v).first
                        a ||= begin
                          mk = Meta::Key.where(:label => "title").first
                          #mongo# TODO user.media_sets.create(:meta_data_attributes => [{:meta_key_id => mk.id, :value => v}])
                          ms = Media::Set.create
                          ms.meta_data.create(:meta_key_id => mk.id, :value => v)
                            
                          #mongo#0409# TODO move to Media::Entry#generate_permissions ??
                          h = {:subject => user, :view => true, :edit => true, :manage => true, :hi_res => true}
                          ms.permissions.create(h)
                          
                          ms
                        end
                    end
      records.compact
    end


  end
end
