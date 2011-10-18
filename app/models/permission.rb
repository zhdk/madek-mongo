# -*- encoding : utf-8 -*-
class Permission
  include Mongoid::Document

  # TODO ??
  #GUEST = :guest #or# PUBLIC = :public
  #LOGGED_IN = :logged_in

  ACTIONS = [:view, :edit, :hi_res, :manage_permissions]

  # OPTIMIZE refactor and include as module directly to media_resource ?? {permission: {view: [], view: [], ...}}
  embedded_in :resource

  ACTIONS.each do |action|
    field action, type: Hash #, default: {:true => [], :false => []}
  end

  def subject_ids
    ACTIONS.map do |key|
      send("#{key}=", {"true" => [], "false" => []}) unless send(key)
      send(key)["true"] + send(key)["false"]
    end.flatten.uniq
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

      send("#{action_sym}=", {"true" => [], "false" => []}) unless send(action_sym)
      send(action_sym)["false"].delete(subject_id)
      send(action_sym)["true"].push(subject_id).uniq!
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

      send("#{action_sym}=", {"true" => [], "false" => []}) unless send(action_sym)
      send(action_sym)["true"].delete(subject_id)
      send(action_sym)["false"].push(subject_id).uniq!
    end
  end

end