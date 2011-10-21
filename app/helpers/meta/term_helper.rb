# -*- encoding : utf-8 -*-
module Meta
  module TermHelper
    
    #mongo#dirty# OPTIMIZE filter
    def display_meta_data_checkboxes(resource_ids)
      resources = Media::Resource.only(:meta_data).find(resource_ids)
  
      meta_key_labels = [ ["keywords", "Schlagworte"], # TODO get german title through definitions: meta_key = MetaKey.where(:label => label).first, etc...
                          ["type", "Gattung"],
                          ["academic year", "Studienjahr"],
                          ["project type", "Projekttyp"],
                          ["institutional affiliation", "Bereich ZHdK"] ]
  
      capture_haml do
        meta_key_labels.each do |label, title|
          meta_terms_h = {}
          resources.each do |r|
            terms = r.meta_data.get(label).value.uniq # FIXME why is not already unique?
            terms.each do |term|
              meta_terms_h[term] ||= []
              meta_terms_h[term] << r.id
            end
          end
  
          h = {}
          all_words = meta_terms_h.sort {|a,b| [b[1].count, a[0].to_s] <=> [a[1].count, b[0].to_s] }
  
          unless all_words.empty?
            haml_tag :h3, :class => "filter_category clearfix" do
              haml_concat link_to title, "#", :class => "filter_category_link"
              haml_tag :span, "", :class => "ui-icon ui-icon-triangle-1-e"
            end
            haml_tag :div, :class => "filter_content", :style => "display: none;" do
              haml_tag :ul do
                all_words.each do |word|
                  haml_tag :li do
                    haml_concat check_box_tag nil, nil, false, :"data-item_ids" => word.last.to_json
                    haml_concat "#{word.first} (<span class='total_ids'>#{word.last.count}</span>)"
                  end
                end
              end
            end
          end
        end
      end
    end
    
  end
end