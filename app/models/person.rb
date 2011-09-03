# -*- encoding : utf-8 -*-
class Person < Subject

  has_and_belongs_to_many :groups
  has_many :upload_sessions, class_name: "Upload::Session" do
    def latest
      first
    end
    def most_recents(limit = 3)
      all(:limit => limit)
    end
  end
  #mongo# TODO ?? has_many :uploaded_media_entries, class_name: "Media::Entry", through: :upload_sessions
  has_and_belongs_to_many :favorite_resources, class_name: "Media::Resource", inverse_of: :subjects # NOTE need inverse_of #mongo# TODO has_many stored_as: Array

  #########################################################

  field :firstname, type: String
  field :lastname, type: String
  field :pseudonym, type: String
  field :birthdate, type: Date
  field :deathdate, type: Date
  field :nationality, type: String
  field :wiki_links, type: String

  #mongo# TODO embedded user class ??
  #field :password, type: String
  #field :last_login_at, type: DateTime
  field :login, type: String
  field :email, type: String
  field :usage_terms_accepted_at, type: DateTime
  
  validates_uniqueness_of :login, :email, :allow_nil => true

  #########################################################

  scope :users, where(:login.exists => true)

  def self.with_media_entries
    #mongo# TODO
    #ids = MetaDatum.joins(:meta_key).where(:meta_keys => {:object_type => self.name}).collect(&:value).flatten.uniq
    #find(ids)
    all
  end

  #########################################################

  def to_s
    name
  end
  
  def name
    a = []
    a << lastname unless lastname.blank? 
    a << firstname unless firstname.blank? 
    r = a.join(", ")
    r += " (#{pseudonym})" unless pseudonym.blank?
    #mongo# TODO r += " [Gruppe]" if is_group?
    r
  end

  #########################################################

  # class method to parse a name out of something that purports 
  # to be a name representing a natural person.
  # Input is presented either as:
  #   Firstname Lastname , or
  #   Lastname, Firstname
  def self.parse(value)
    #TODO untrivialise this name splitter
    #TODO does this really belong here?
    value.gsub!(/[*%;]/,'')
    if value.include?(",") # input comes to us as lastname<comma>firstname(s)
      x = value.downcase.strip.squeeze(" ").split(/\s*,\s*/,2)
      fn = x.pop
      ln = x.pop
    else # Last word is family name, everything else is firstname(s)
      x = value.downcase.strip.split(/\s{1}/,-1)
      ln = x.pop
      fn = x.each {|e| e.capitalize }.join(' ')
    end
    # OPTIMIZE
    fn = nil if fn.blank?
    ln = nil if ln.blank?
    return fn, ln
  end

  def self.split(values)
    values.map {|v| v.respond_to?(:split) ? v.split(';') : v }.flatten
  end
  
end