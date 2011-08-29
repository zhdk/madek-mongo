# -*- encoding : utf-8 -*-
class Permission
  include Mongoid::Document

  embedded_in :resource
  belongs_to :subject
  
  field :view, type: Boolean #mongo# TODO rename to :read
  field :edit, type: Boolean #mongo# TODO rename to :update
  field :hi_res, type: Boolean
  field :manage, type: Boolean #mongo# TODO rename to :admin ?? or :owner ??
  key :subject_id

  #doesn't work# validates_uniqueness_of :subject_id
  
  validate do
    errors.add(:base, "When the subject is not defined, at least one action must be true") if subject.nil? and not [view, edit, hi_res, manage].include?(true)
  end

  #########################################################

  def set_actions(hash)
    if hash.empty?
      destroy
    else
      hash.each_pair do |key, value|
        send("#{key}=", value)
      end
      save
    end
  end

end