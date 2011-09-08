# -*- encoding : utf-8 -*-
class UsageTerm
  include Mongoid::Document
  include Mongoid::Timestamps::Updated

  # TODO embeds UsageTerm, Copyrights and Context to an Application collection ??

  field :title, type: String
  field :version, type: String
  field :intro, type: String
  field :body, type: String
  
  def self.current
    r = first
    r ||= create(:title => "Nutzungsbedingungen")
  end
end