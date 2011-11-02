# -*- encoding : utf-8 -*-
class Permission
  include Mongoid::Document

  # TODO ??
  #GUEST = :guest #or# PUBLIC = :public
  #LOGGED_IN = :logged_in

  # TODO move to _parent::ACTIONS ??
  # for Media::Set => [:view, :edit(_meta_data), :manage_permissions, :add_resource, :remove_resource]
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
      # OPTIMIZE
      set(action_sym, send(action_sym))
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
      # OPTIMIZE
      set(action_sym, send(action_sym))
    end
  end

  #################################################
  class << self
    
    #wip#4 merge to ResourcesController#edit_permissions
    def compare(resources)
      permissions = resources.map(&:permission)
      combined_permissions = { "public" => {:view => false, :edit => false, :hi_res => false, :manage_permissions => false, :name => "Öffentlich", :type => 'nil'},
                               "Person" => [],
                               "Group" => [] }

      all_subjects = permissions.map(&:subject_ids).flatten.uniq
      all_subjects.each do |subject_id|
        if subject_id == :public
          ACTIONS.each do |key|
            combined_permissions["public"][key] = case permissions.select {|p| p.send(key)["true"].include?(:public) }.size
              when resources.size
                true
              when 0
                false
              else
                :mixed
            end
          end
        else
          subject = Subject.find(subject_id)
          combined_permissions[subject._type] << begin
            h = {:id => subject.id, :name => subject.to_s, :type => subject._type}
            ACTIONS.each do |key|
              h[key] = case permissions.select {|p| p.send(key)["true"].include?(subject.id) }.size
                when resources.size
                  true
                when 0
                  false
                else
                  :mixed
              end
            end
            h
          end
        end
      end

      return combined_permissions
    end
    
  end
    
  #################################################

end