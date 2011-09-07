# -*- encoding : utf-8 -*-
module Meta
  class Department < Group
  
    field :ldap_id, type: String
    field :ldap_name, type: String
  
    default_scope order_by(:name)
  
    def to_s
      "#{name} (#{ldap_name})"
    end
  
    def to_limited_s(n = 80)
      if to_s.mb_chars.size > n
        "#{to_s.mb_chars.limit(n)}..."
      else
        to_s
      end
    end
  
    def is_readonly?
      true
    end
  
  ##########################################
  
    def self.fetch_from_ldap(ldap_config_file_file = nil)
      ldap_config_file ||= YAML::load_file("#{Rails.root}/config/LDAP.yml")
      
      ldap = Net::LDAP.new :host => ldap_config_file[Rails.env]["host"],
                           :port => ldap_config_file[Rails.env]["port"].to_i,
                           :encryption => ldap_config_file[Rails.env]["encryption"].to_sym,
                           :base => ldap_config_file[Rails.env]["base"],
                           :auth => {
                             :method=> :simple,
                             :username => ldap_config_file[Rails.env]["bind_dn"],
                             :password => ldap_config_file[Rails.env]["bind_pwd"] } 
  
      if ldap.bind
        #ic = Iconv.new('utf-8//IGNORE//TRANSLIT', 'utf-8')
        transaction do
          ldap.search(:attributes => ["name", "extensionAttribute1", "extensionAttribute3"], # [ "cn" , "displayName", "extensionAttribute2"],
                      :filter => nil,
                      :return_result => true ) do |entry|
                        next if entry["extensionattribute3"].empty?
                        r = self.find_or_create_by_ldap_id(:ldap_id => entry["extensionattribute3"].first)
                        r.update_attributes(:ldap_name => entry["name"].first, :name => entry["extensionattribute1"].first) #ic.iconv(entry["displayname"].first)
          end
        end
      end
      
    end
  
  end
end
