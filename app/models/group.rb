# -*- encoding : utf-8 -*-
class Group < Subject

  has_and_belongs_to_many :people

  field :name, type: String

  scope :departments, where(:_type => "Meta::Department")

  def is_readonly?
    ["Admin", "Expert", "MIZ-Archiv", "ZHdK (Zürcher Hochschule der Künste)"].include?(name)
  end
    
end