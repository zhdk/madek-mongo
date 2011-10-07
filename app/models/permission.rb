# -*- encoding : utf-8 -*-
class Permission
  include Mongoid::Document

  # TODO ??
  #GUEST = :guest #or# PUBLIC = :public
  #LOGGED_IN = :logged_in

  ACTIONS = [:view, :edit, :hi_res, :manage_permissions] # view = 2^0 = 1; edit = 2^1 = 2; hi_res = 2^2 = 4; manage = 2^3 = 8

  # OPTIMIZE refactor and include as module directly to media_resource ?? {permission: {view: [], view: [], ...}}
  embedded_in :resource

  # NOTE using dynamic fields {subject_id => action_bits, "4e8793e9c264f8e0c6000001" => 11, ... }
  def subject_ids
    attributes.select{|x| not fields.keys.include?(x)}.keys
  end

  ##########################################
  
  # hash is {action => subject}
  def grant(h)
    h.each_pair do |action, subject|
      subject_id = if subject == :public
        :public
      elsif subject.is_a? Subject
        subject.id
      end
      next unless subject_id
      
      action_sym = action.to_sym
      action_sym = :manage_permissions if action_sym == :manage

      #i = ACTIONS.index(action_sym)
      #next unless i
      attributes[subject_id.to_s] ||= [] # 0
      attributes[subject_id.to_s] << action_sym unless attributes[subject_id.to_s].include?(action_sym) # |= 2 ** i
    end
  end

  # hash is {action => subject}
  def deny(h)
    h.each_pair do |action, subject|
      subject_id = if subject == :public
        :public
      elsif subject.is_a? Subject
        subject.id
      end
      next unless subject_id

      action_sym = action.to_sym
      action_sym = :manage_permissions if action_sym == :manage

      #i = ACTIONS.index(action_sym)
      #next unless i
      attributes[subject_id.to_s] ||= [] # 0
      attributes[subject_id.to_s].delete(action_sym) # &= ~(2 ** i)
    end
  end

end