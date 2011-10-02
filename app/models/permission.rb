# -*- encoding : utf-8 -*-
class Permission
  include Mongoid::Document

  # TODO ??
  #GUEST = :guest #or# PUBLIC = :public
  #LOGGED_IN = :logged_in

  # OPTIMIZE refactor and include as module directly to media_resource ?? {permission: {view: [], view: [], ...}}
  embedded_in :resource

  # TODO dynamic fields ?? {subject_id => action_bits, "4e8793e9c264f8e0c6000001" => 11, ... }
  
  field :view, type: Hash #, default: {:true => [], :false => []} # [] # proc { @view || [] } #mongo# TODO rename to :read
  field :edit, type: Hash #, default: {:true => [], :false => []} # [] # proc { @edit || [] } #mongo# TODO rename to :update
  field :hi_res, type: Hash #, default: {:true => [], :false => []} # [] # proc { @hi_res || [] } # TODO only for media_entry
  field :manage, type: Hash #, default: {:true => [], :false => []} # [] # TODO 1 subject # proc { @manage || [] } #mongo# TODO rename to :admin ?? or :owner ??

=begin
  after_initialize do
    # NOTE set default preventing same references
    fields.values.select{|f| f.options[:type] == Hash }.map(&:name).each do |field_name|
      attributes[field_name] = {:true => [], :false => []} if attributes[field_name].blank?
    end
  end
=end

  #mongo# TODO validates_uniqueness :subject
  # before_validation fields...uniq!

=begin #tmp# doesn't work
  # NOTE set default just on request
  fields.values.select{|f| f.options[:type] == Array }.map(&:name).each do |field_name|
    define_method(field_name) do |*args|
      attributes[field_name] ||= []
    end
  end
=end

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

      send("#{action}=", {"true" => [], "false" => []}) unless send(action)
      send(action)["false"].delete(subject_id)
      send(action)["true"].push(subject_id).uniq!
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

      send("#{action}=", {"true" => [], "false" => []}) unless send(action)
      send(action)["true"].delete(subject_id)
      send(action)["false"].push(subject_id).uniq!
    end
  end

end