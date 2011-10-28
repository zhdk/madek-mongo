# -*- encoding : utf-8 -*-
class UsersController < ApplicationController

  def index
    #mongo# filter only users Person#scope
    people = Person.search(params[:term]) unless params[:term].blank?

    respond_to do |format|
      #tmp# format.html
      format.js { render :json => people.map {|x| {:id => x.id, :value => x.to_s} } }
    end
  end

#mongo#
=begin
  def show
    # TODO refactor from ApplicationController#root
    redirect_to user_media_entries_path(params[:id])
  end
=end

#####################################################

  def usage_terms
    if request.post?
      # OPTIMIZE check if really submitted the form (hidden variable?)
      current_user.usage_terms_accepted!
      redirect_to root_path
    else
      @usage_term = UsageTerm.current
      
      @title = "Medienarchiv der Künste: #{@usage_term.title}"
      @disable_user_bar = true
      @disable_search = true
    end
  end

end
