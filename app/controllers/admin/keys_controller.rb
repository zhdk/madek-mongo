# -*- encoding : utf-8 -*-
class Admin::KeysController < Admin::AdminController # TODO rename to Admin::Meta::KeysController ??

  before_filter :pre_load

  def index
    @keys = Meta::Key.order_by(:label)
  end

  def new
    @key = Meta::Key.new
    respond_to do |format|
      format.js
    end
  end

  def create
    Meta::Key.create(params[:meta_key])
    redirect_to admin_keys_path    
  end

  def edit
    respond_to do |format|
      format.js
    end
  end

  def update
    meta_terms_attributes = params[:meta_key].delete(:meta_terms_attributes)

    params[:reassign_term_id].each_pair do |k, v|
      next if v.blank?
      from = @key.meta_terms.find(k)
      to = @key.meta_terms.find(v)
      next if from == to
      from.reassign_meta_data_to_term(to, @key)
      meta_terms_attributes.values.detect{|x| x[:id].to_i == from.id}[:_destroy] = 1
    end if params[:reassign_term_id]

    if params[:term_positions]
      positions = CGI.parse(params[:term_positions])["position[]"]
      #mongo# FIXME
      #positions.each_with_index do |id, i|
      #  @key.meta_key_meta_terms.where(:meta_term_id => id).first.update_attributes(:position => i+1)
      #end
      #mongo#tmp# @key.meta_terms = positions.map {|id| @key.meta_terms.detect {|mt| mt.id.to_s == id} }
    end

    meta_terms_attributes.each_value do |h|
      if h[:id].nil? and LANGUAGES.any? {|l| not h[l].blank? }
        term = Meta::Term.find_or_create_by(h)
        @key.meta_terms << term
        #old??# h[:id] = term.id
      elsif h[:_destroy].to_i == 1
        term = @key.meta_terms.find(h[:id])
        @key.meta_terms.delete(term)
      end
    end if meta_terms_attributes
 
    @key.update_attributes(params[:meta_key])
    redirect_to admin_keys_path
  end

  def destroy
    @key.destroy if @key.meta_definitions.empty?
    redirect_to admin_keys_path
  end

#####################################################

  def mapping
    @graph = Meta::Key.keymapping_graph
    respond_to do |format|
      format.html
      format.js { render :layout => false }
    end
  end

#####################################################

  private

  def pre_load
      params[:key_id] ||= params[:id]
      @key = Meta::Key.find(params[:key_id]) unless params[:key_id].blank?
  end

end
