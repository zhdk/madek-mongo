#Copyright.init
#Permission.init
#Meta::Department.fetch_from_ldap
#Meta::Date.parse_all

######################################

#tmp# [Subject, Meta::Context, Meta::Term, Meta::Key, Media::Resource].each {|x| x.destroy_all }

#########################################################

=begin
#old# guest_user = User.create(:name => "Guest")

files = Dir[File.join("/Users/itz/Documents/workspace/MAdeK_doc/Testbilder/Testbilder_Fotostudio_IPTC_LR/", '**', '*')]
files.each do |f|  
  media_entry = Media::Entry.new
  media_entry.store_file(f)
  #old# media_entry.permissions.build(:subject => guest_user, :view => true)
  media_entry.permissions.build(:view => true)
  media_entry.permissions.build(:subject => user, :view => true)
  media_entry.save
end
=end

##########################################################################
@map = { Meta::Copyright => {},
         Meta::Term => {},
         Meta::Key => {},
         Media::Set => {},
         Media::Entry => {},
         "User" => {},
         "User_favorites" => {},
         Person => {},
         Group => {}
       }

#old# parsed_import = JSON.parse(`curl http://localhost:4000/admin/media_entries/export.js`)
file_path = "#{Rails.root}/db/full_export.json"
#parsed_import = YAML.load(File.read(file_path))
parsed_import = JSON.parse(File.read(file_path))

##########################################################################
  
puts "Importing terms..."

def factory_klass(h, klass)
  id = h.delete("id")
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v unless v.nil?}
  @map[klass][id] = klass.create(attr)
end

parsed_import["meta_terms"].each do |h|
  factory_klass(h, Meta::Term)
end

##########################################################################

puts "Importing keys..."
parsed_import["meta_keys"].each do |h|
  meta_term_ids = h.delete("meta_term_ids")
  h["object_type"] = "Meta::#{h["object_type"]}" if %w(Keyword Copyright).include? h["object_type"] 
  meta_key = factory_klass(h, Meta::Key)
  meta_key.meta_terms << meta_term_ids.map {|id| @map[Meta::Term][id] } unless meta_term_ids.blank?
end

##########################################################################

puts "Importing contexts..."

def factory_meta_context(h)
  field = h.delete("meta_field")
  definitions = h.delete("meta_key_definitions")
  
  klass = Meta::Context
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v }
  [:label, :description].each {|x| attr[x] = @map[Meta::Term][field[x.to_s]] if field[x.to_s] }
  r = klass.create(attr)
  
  definitions.each do |definition|
    field = definition.delete("meta_field")
    attr = {:meta_key => @map[Meta::Key][definition["meta_key_id"]]}
    [:label, :description, :hint].each {|x| attr[x] = @map[Meta::Term][field[x.to_s]] if field[x.to_s] }
    r.meta_definitions.create(attr)
  end
end

parsed_import["meta_contexts"].each do |h|
  factory_meta_context(h)
end

##########################################################################

puts "Importing copyrights..."

def factory_copyright(h)
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v unless %w(id parent_id).include?(k) }
  klass = Meta::Copyright
  @map[klass][h["id"]] = klass.create(attr)  
end

parsed_import["copyrights"].each do |h|
  factory_copyright(h)
end
klass = Meta::Copyright
parsed_import["copyrights"].each do |h|
  next unless h["parent_id"]
  child = @map[klass][h["id"]]
  parent = @map[klass][h["parent_id"]]
  parent.children << child
end

##########################################################################

puts "Importing people..."

def factory_subject(h, klass)
  id = h.delete("id")
  user = h.delete("user")
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v }
  [:login, :email].each {|k| attr[k] = user[k.to_s] } if user
  subject = klass.create(attr)
  @map[klass][id] = subject
  if user
    @map["User"][user["id"]] = subject
    @map["User_favorites"][user["id"]] = user["favorite_ids"]
  end
  subject
end

parsed_import["subjects"]["people"].each do |h|
  factory_subject(h, Person)
end

##########################################################################

puts "Importing groups..."
parsed_import["subjects"]["groups"].each do |h|
  person_ids = h.delete("person_ids")
  group = factory_subject(h, Group)
  group.people << person_ids.map {|id| @map[Person][id] }
end

##########################################################################

puts "Importing media_sets..."

def factory_permissions(h, resource)
  h.each do |p|
    subject = case p["subject_type"]
      when "User"
        @map["User"][p["subject_id"]]
      when "Group"
        @map[Group][p["subject_id"]]
    end
    
    attr = {:subject => subject}
    p["actions"].each_pair {|k,v| attr[k.to_sym] = v }
    resource.permissions.build(attr)
  end
  resource.permissions.delete_if {|x| not x.valid? }
end

def factory_meta_data(h, resource)
  h.each do |md|
    value = md.delete("value")
    meta_key = @map[Meta::Key][md["meta_key_id"]]
    meta_data = resource.meta_data.build({meta_key: meta_key})
    case meta_key.object_type
      when "Person"
        value.each do |x|
          meta_data.meta_references.build(:reference => @map[Person][x])
        end
      when "Meta::Copyright"
        value.each do |x|
          meta_data.meta_references.build(:reference => @map[Meta::Copyright][x])
        end
      when "Meta::Department"
        # TODO department as subclass of group ??
        value.each do |x|
          meta_data.meta_references.build(:reference => @map[Group][x])
        end
      when "Meta::Date"
        # TODO use Ruby Date directly ??
        value.each do |x|
          meta_data.meta_dates.build(x)
        end
      when "Meta::Country"
        # TODO define a country class ??
        meta_data.value = value
      when "Meta::Term"
        value.each do |x|
          meta_data.meta_keywords.build(:meta_term => @map[Meta::Term][x])
        end
      when "Meta::Keyword"
        md["deserialized_value"].each do |dv|
          meta_data.meta_keywords.build(:meta_term => @map[Meta::Term][dv["meta_term_id"]],
                                     :created_at => dv["created_at"],
                                     :subject => @map["User"][dv["user_id"]])
        end
      else
        meta_data.value = value 
    end
    meta_data.save
  end
end

def factory_resource(h, klass)
  resource = klass.new
  #tmp# media_entry.store_file(f)
  factory_permissions(h["permissions"], resource)
  factory_meta_data(h["meta_data"], resource)
  resource.save
  @map[klass][h["id"]] = resource
end

parsed_import["media_sets"].each do |h|
  factory_resource(h, Media::Set)
end

##########################################################################

puts "Importing media_entries..."
parsed_import["media_entries"].each do |h|
  media_file = h.delete("media_file")
  media_entry = factory_resource(h, Media::Entry)
  #media_entry.media_sets << h["media_set_ids"].map {|id| Media::Set.find(@map[Media::Set][id]) }
  media_entry.media_sets << h["media_set_ids"].map {|id| @map[Media::Set][id] }
  
  previews = media_file.delete("previews")
  attr = {}
  media_file.each_pair {|k,v| attr[k.to_sym] = v }
  mf = media_entry.create_media_file(attr)
  previews.each do |p|
    mf.previews.create(p)
  end
end

##########################################################################

puts "Importing favorites..."
@map["User_favorites"].each_pair do |user_id, ids|
  @map["User"][user_id].favorite_resources << ids.map {|id| @map[Media::Entry][id] }
end












