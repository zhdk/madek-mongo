#Copyright.init
#Permission.init
#Meta::Department.fetch_from_ldap
#Meta::Date.parse_all

##########################################################################
@map = { Meta::Copyright => {},
         Meta::Term => {},
         Meta::Key => {},
         Meta::Context => {},
         Media::Set => {},
         Media::Entry => {},
         "User" => {},
         "User_favorites" => {},
         "Upload_sessions" => {},
         Person => {},
         Group => {},
         Meta::Department => {}
       }

#old# parsed_import = JSON.parse(`curl http://localhost:4000/admin/media_entries/export.js`)

#tmp# file_path = "#{Rails.root}/db/full_export.json"
file_path = "#{Rails.root}/db/minimal_setup.json"
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
  id = h.delete("id")
  field = h.delete("meta_field")
  definitions = h.delete("meta_key_definitions")
  
  klass = Meta::Context
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v }
  [:label, :description].each {|x| attr[x] = @map[Meta::Term][field[x.to_s]] if field[x.to_s] }
  @map[klass][id] = r = klass.create(attr)
  
  definitions.each do |definition|
    field = definition.delete("meta_field")
    attr = {:meta_key => @map[Meta::Key][definition["meta_key_id"]]}
    # TODO remove position ??
    [:position, :key_map, :key_map_type].each {|x| attr[x] = definition[x.to_s] if definition[x.to_s] }
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

puts "Importing usage_terms..."

parsed_import["usage_terms"].each do |h|
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v  }
  klass = UsageTerm
  klass.create(attr)  
end

##########################################################################

def factory_subject(h, klass)
  id = h.delete("id")
  user = h.delete("user")
  attr = {}
  h.each_pair {|k,v| attr[k.to_sym] = v }
  if user
    [:login, :email].each {|k| attr[k] = user[k.to_s] }
    attr[:usage_terms_accepted_at] = DateTime.parse(user["usage_terms_accepted_at"]) if user["usage_terms_accepted_at"]
  end
  subject = klass.create(attr)
  @map[klass][id] = subject
  if user
    @map["User"][user["id"]] = subject
    @map["User_favorites"][user["id"]] = user["favorite_ids"]
    
    user["upload_sessions"].each do |x|
      @map["Upload_sessions"][x["id"]] = subject.upload_sessions.create(:created_at => x["created_at"], :is_complete => x["is_complete"])
    end
  end
  subject
end

people = parsed_import["subjects"]["people"] if parsed_import["subjects"]
if people
  puts "Importing people..."
  people.each do |h|
    factory_subject(h, Person)
  end
end

##########################################################################

groups = parsed_import["subjects"]["groups"] if parsed_import["subjects"]
if groups
  puts "Importing groups..."
  groups.each do |h|
    person_ids = h.delete("person_ids")
    type = h.delete("type")
    group = factory_subject(h, type.constantize)
    group.people << person_ids.map {|id| @map[Person][id] } unless person_ids.blank?
  end
end

##########################################################################

def factory_permissions(h, resource)
  h.each do |p|
    subject = case p["subject_type"]
      when "User"
        @map["User"][p["subject_id"]]
      when "Group"
        @map[Group][p["subject_id"]]
      else
        :public if p["subject_id"].nil?
    end
    next unless subject
    p["actions"].each_pair {|k,v| resource.permission.send((v ? :grant : :deny), {k => subject}) }
  end
end

def factory_meta_data(h, resource)
  h.each do |md|
    value = md.delete("value")
    meta_key = @map[Meta::Key][md["meta_key_id"]]
    v = case meta_key.object_type
      when "Person", "Meta::Copyright", "Meta::Department", "Meta::Term"
        value.map {|x| @map[meta_key.object_type.constantize][x] }
      when "Meta::Keyword"
        md["deserialized_value"].map do |dv|
          { :meta_term => @map[Meta::Term][dv["meta_term_id"]],
            :created_at => dv["created_at"],
            :subject => @map["User"][dv["user_id"]] }
        end
      when "Meta::Date"
        value
      when "Meta::Country"
        value
      else
        value 
    end
    resource.set_data(meta_key, v)
  end
end

def factory_edit_sessions(h, resource)
  h.each do |x|
    subject = @map["User"][x["user_id"]]
    resource.edit_sessions.build({:subject => subject, :created_at => x["created_at"]})
  end
end

def factory_resource(h, klass)
  resource = klass.new
  factory_permissions(h["permissions"], resource)
  factory_meta_data(h["meta_data"], resource)
  factory_edit_sessions(h["edit_sessions"], resource)
  resource.save
  @map[klass][h["id"]] = resource
end

media_sets = parsed_import["media_sets"]
if media_sets
  puts "Importing media_sets..."
  media_sets.each do |h|
    media_set = factory_resource(h, Media::Set)
    media_set.individual_contexts << h["individual_context_ids"].map {|id| @map[Meta::Context][id] }
  end
  parsed_import["media_sets"].each do |h|
    next if h["child_ids"].blank?
    @map[Media::Set][h["id"]].media_resources << h["child_ids"].map {|id| @map[Media::Set][id] }
  end
end

##########################################################################

media_featured_set_id = parsed_import["media_featured_set_id"]
if media_featured_set_id
  puts "Importing media_featured_set..."
  @map[Media::Set][media_featured_set_id].update_attributes(:is_featured => true)
end

##########################################################################

media_entres = parsed_import["media_entries"]
if media_entres
  puts "Importing media_entries..."
  media_entries.each do |h|
    media_file = h.delete("media_file")
    media_entry = factory_resource(h, Media::Entry)
    media_entry.media_sets << h["media_set_ids"].map {|id| @map[Media::Set][id] }
  
    @map["Upload_sessions"][h["upload_session_id"]].media_entries << media_entry
    
    #old# previews = media_file.delete("previews")
    attr = {}
    media_file.each_pair {|k,v| attr[k.to_sym] = v }
    mf = media_entry.create_media_file(attr)
    #old# previews.each {|p| mf.previews.create(p)}
  end
end

##########################################################################

snapshots = parsed_import["snapshots"]
if snapshots
  puts "Importing snapshots..."
  snapshots.each do |h|
    media_file = h.delete("media_file")
    snapshot_media_entry = factory_resource(h, Media::Entry)
  
    if(media_entry = @map[Media::Entry][h["media_entry_id"]])
      media_entry.snapshot_media_entry = snapshot_media_entry
      media_entry.save
    end
  
    attr = {}
    media_file.each_pair {|k,v| attr[k.to_sym] = v }
    mf = snapshot_media_entry.create_media_file(attr)
  end
end

##########################################################################

favorites = @map["User_favorites"]
if favorites
  puts "Importing favorites..."
  favorites.each_pair do |user_id, ids|
    @map["User"][user_id].favorite_resources << ids.map {|id| @map[Media::Entry][id] }
  end
end

