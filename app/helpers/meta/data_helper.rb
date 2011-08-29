# -*- encoding : utf-8 -*-
module Meta
  module DataHelper
    
    def display_meta_data_for(resource, context)
      meta_data = resource.meta_data.for_context(context, false)
      capture_haml do
        if meta_data.empty?
          haml_tag :div, _("Es sind keine Metadaten zu diesem Kontext bereit gestellt."), :class => "meta_data_comment"
        else
          haml_tag :table, :class => "meta_data" do
            meta_data.each do |meta_datum|
              next if meta_datum.to_s.blank? #tmp# OPTIMIZE 2007
              definition = context.meta_definitions.where(:meta_key_id => meta_datum.meta_key_id).first
              haml_tag :tr do
                haml_tag :td do
                  haml_tag :label, definition.label
                end
                haml_tag :td, formatted_value(meta_datum)
              end
            end
          end
        end
      end
    end

    def display_core_meta_data_for(resource)
      context = Meta::Context.core
      meta_data = resource.meta_data.for_context(context)
      capture_haml do
        meta_data.each do |meta_datum|
          definition = context.meta_definitions.where(:meta_key_id => meta_datum.meta_key_id).first
          haml_tag :h4, definition.label, :style => "margin-top: 10px;"
          haml_tag :div, :meta_key_id => meta_datum.meta_key_id do
            haml_tag :span, formatted_value(meta_datum), :content => "value"
          end
        end
      end
    end

    # TODO merge with Meta::Datum#to_s
    def formatted_value(meta_datum)
      capture_haml do
        unless meta_datum.meta_keywords.blank?
          s = meta_datum.meta_keywords.map do |v|
            #mongo# TODO link_to dv, filter_search_path(:meta_key_id => meta_datum.meta_key, :meta_term_id => dv.id), :method => :post, :remote => true, :"data-meta_term_id" => dv.id
            link_to v, resources_path(:query => v.to_s)
          end
          haml_concat s.join(', ')
        else
          s = meta_datum.to_s
          #mongo# TODO haml_concat auto_link(s, :all, :target => "_blank")
          haml_concat s
        end
      end
    end

  ###########################################################

    def widget_meta_terms(meta_datum, meta_key, meta_terms, ui)
      if meta_key.is_extensible_list? or meta_terms.size > 16
        widget_meta_terms_multiselect(meta_datum, meta_key)
      else
        half_size = (meta_terms.size / 2) + (meta_terms.size % 2)
        content_tag :ul, :class => "meta_terms" do
          c = content_tag :li do
            content_tag :ul do
              meta_terms[0..(half_size-1)].collect do |term|
                checkbox_for_term(term, meta_datum, ui)
              end.join.html_safe
            end
          end
          c += content_tag :li do
            content_tag :ul do
              meta_terms[half_size..-1].collect do |term|
                checkbox_for_term(term, meta_datum, ui)
              end.join.html_safe
            end
          end
        end
      end
    end

  ###########################################################
  
    def widget_meta_countries(meta_datum, meta_key)
      file = "#{Rails.root}/config/definitions/helpers/country_codes.yml"
      entries = YAML.load(File.read(file))
  
      all_options = entries.collect {|x| ["#{x["country_code"]} - #{x["country_name"]}", x["country_code"]]}.sort
      selected_option = meta_datum.object.value
      
      all_options << [selected_option, selected_option] unless all_options.collect{|x| x[1]}.include?(selected_option)
      
      meta_datum.select :value, options_for_select(all_options, selected_option), {:include_blank => true}
    end

  ###########################################################
    
    # NEW generic multi select plugin
    def widget_meta_terms_multiselect(meta_datum, meta_key)
      case meta_key.object_type.constantize.name
        when "Meta::Department"
          selected = Array(meta_datum.object.value)
          all_options = Meta::Department.all.collect {|x| {:label => x.to_s, :id => x.id, :selected => selected.include?(x.id)} }
        when "Meta::Term"
          selected = Array(meta_datum.object.value)
          all_options = meta_key.meta_terms.collect {|x| {:label => x.to_s, :id => x.id, :selected => selected.include?(x.id)}}
        when "Person"
          selected = Array(meta_datum.object.value)
          @people ||= meta_key.object_type.constantize.with_media_entries
          all_options = @people.collect {|x| {:label => x.to_s, :id => x.id, :selected => selected.include?(x.id)}}
        when "Keyword"
          keywords = meta_datum.object.deserialized_value
          meta_term_ids = keywords.collect(&:meta_term_id)
          all_grouped_keywords = Keyword.group(:meta_term_id)
          all_grouped_keywords = all_grouped_keywords.where(["meta_term_id NOT IN (?)", meta_term_ids]) unless meta_term_ids.empty?
          all_options = keywords.collect {|x| {:label => x.to_s, :id => x.meta_term_id, :selected => true}}
          all_options += all_grouped_keywords.collect {|x| {:label => x.to_s, :id => x.meta_term_id, :selected => false}}
          all_options.sort! {|a,b| a[:label].downcase <=> b[:label].downcase}
      end
  
      is_extensible = (meta_key.is_extensible_list? or ["Keyword", "Person"].include?(meta_key.object_type))
      with_toggle = !["keywords", "author", "creator", "description author", "description author before import"].include?(meta_key.label)
  
      h = content_tag :div, :class => "madek_multiselect_container",
                            :"data-is_extensible" => is_extensible,
                            :"data-with_toggle" => with_toggle do 
        a = content_tag :ul, :class => "holder" do
          content_tag :li, :class => "input_holder" do
            text_field_tag "autocomplete_search", nil, :style => "outline: none; border: none;", :id => "#{meta_key.label.gsub(/\W+/, '_')}_autocomplete_search",
                            :"data-all_options" => "#{all_options.to_json}",
                            :"data-field_name_prefix" => "#{meta_datum.object_name}"
          end
        end
      end
    
          
      @js_3 ||= false
      unless @js_3
        @js_3 = true
        h += content_tag :script, :type => "text/x-jquery-tmpl", :id => "madek_multiselect_item" do
          begin
          <<-HERECODE
            <li class='bit-box'>
              ${label}
              <input type='hidden' name='${field_name_prefix}[value][]' value='${id}'>
              <a class="closebutton" href="#"></a>
            </li>
          HERECODE
          end.html_safe
        end
        h += stylesheet_link_tag "jquery/fcbkcomplete.css", "jquery/fcbkcomplete_custom.css"
        h += javascript_tag do
          begin
          <<-HERECODE
            $(document).ready(function(){
              function do_nothing() {
                    return false;
              };
              $(".dialog_link").click(function(e){
                // prevent double click on link
                $(e.target).click(do_nothing);
                setTimeout(function(){
                  $(e.target).unbind('click', do_nothing);
                }, 1000);
                var source = $(this);
                var next_container = source.next();
                if(next_container.length > 0){
                  next_container.slideToggle();
                  source.children("img:last").toggleClass("expanded");
                }else{
                  $.ajax({
                    url: source.attr("href"),
                    dataType: 'html',
                    success: function(response){
                      source.children("img:last").toggleClass("expanded");
                      source.after(response);
                      source.next().hide().slideDown();
                      $("form[data-remote] input:submit").click(function(event){
                        $(this).closest("form").trigger("submit");
                        return false;
                      });
  
                      if(source.closest("[data-meta_key]").data("meta_key") == "keywords"){
                        hide_selected_keywords(source.prev(".madek_multiselect_container").find("ul.holder")); 
                      }else{
                        $("form.new_person").bind("ajax:success", function(xhr, item, status){
                          if (item.id != null) {
                            var search_field = $(this).closest("[data-meta_key]").find("input[name='autocomplete_search']");
                            add_to_selected_items(item, search_field, true);
                          };  
                          source.children("img:last").toggleClass("expanded");
                          $(this).closest(".tabs").remove();
                        });
                      }
                    }
                  });
                }
                return false;                  
              });                   
            });
          HERECODE
          end.html_safe
        end
      end
  
      h
    end
  
    def field_tag(meta_datum, context, autofocus = false, with_actions = false)
      h = meta_datum.hidden_field :meta_key_id
  
      meta_key = meta_datum.object.meta_key
      field_id = "#{sanitize_to_id(meta_datum.object_name)}_value"
      definition = context.meta_definitions.where(:meta_key_id => meta_datum.object.meta_key_id).first
      is_required = (definition.is_required ? true : nil)
      key_id = meta_datum.object.meta_key_id
  
      if meta_key.object_type == "Meta::Country"
        h += widget_meta_countries(meta_datum, meta_key)
  
      elsif meta_key.object_type
        klass = meta_key.object_type.constantize
              
        case klass.name
          # TODO set String for 'subject' key, TODO multiple fields for array 
          #       when "String"
          #          h += text_area_tag "media_entry[meta_data_attributes][0][value]", meta_datum.object.to_s
          when "Keyword"
            h += widget_meta_terms_multiselect(meta_datum, meta_key)
            h += link_to icon_tag("button_add_keyword"), keywords_media_entries_path, :class => "dialog_link", :style => "margin-top: .5em;"
  
          when "Meta::Term"
            meta_terms = meta_key.meta_terms
            ui = (definition.length_max and definition.length_max == 1 ? :radio_button : :check_box )
            h += widget_meta_terms(meta_datum, meta_key, meta_terms, ui)
  
          when "Person"
            h += widget_meta_terms_multiselect(meta_datum, meta_key)
            h += link_to icon_tag("button_add_person"), new_person_path, :class => "dialog_link", :style => "margin-top: .5em;"
            
          when "Meta::Date"
            at = from = to = at_time = ""
            selected_option = "freetext"
            case meta_datum.object.meta_dates.size
              when 2
                f = meta_datum.object.meta_dates.first
                l = meta_datum.object.meta_dates.last
                if f.parsed and l.parsed
                  #old# from = f.to_s
                  #old# to = l.to_s
                  from = f.parsed.to_formatted_s(:date)
                  to = l.parsed.to_formatted_s(:date)
                  selected_option = "from-to"
                end
              when 1
                f = meta_datum.object.meta_dates.first
                if f.parsed
                  #old# at = f.to_s
                  at = f.parsed.to_formatted_s(:date)
                  if f.parsed.seconds_since_midnight > 0
                    at_time = f.parsed.to_formatted_s(:time_full) + " " + f.parsed.formatted_offset 
                  end
                  selected_option = "at"
                end
            end
  
            h += select_tag "dateSelect", options_for_select([["am", "at"], ["von - bis", "from-to"], ["Freie Eingabe", "freetext"]], selected_option)
            
            h += content_tag :span, :class => "dates" do
              a = content_tag :span, :rel => "at" do
                b = text_field_tag "datepicker_at_#{key_id}", at, :class => "datepicker", :placeholder => "TT.MM.JJJJ"
                b += text_field_tag "at_#{key_id}_tiem", at_time, :class => "time", :placeholder => "HH:MM:SS +HH:MM" unless at_time.blank?
                b
              end
              a += content_tag :span, :rel => "from-to" do
                b = text_field_tag "datepicker_from_#{key_id}", from, :class => "datepicker", :placeholder => "TT.MM.JJJJ"
                b += " - "
                b += text_field_tag "datepicker_to_#{key_id}", to, :class => "datepicker", :placeholder => "TT.MM.JJJJ"
              end
              a += content_tag :span, :rel => "freetext" do
                meta_datum.object.value = meta_datum.object.to_s
                meta_datum.text_field :value, :placeholder => "Wird als Freitext gespeichert."
              end
            end
  
            @js_1 ||= false
            unless @js_1
              @js_1 = true
              locale = "de-CH"
              h += javascript_include_tag "plugins/i18n/jquery.ui.datepicker-#{locale}"
              h += javascript_tag do
                begin
                <<-HERECODE
                  $(document).ready(function(){
                    $("[name='dateSelect']").change(function(){
                      var selected_value = $(this).val();
                      $(this).next(".dates").find("span").hide();
                      var to_show = $(this).next(".dates").find("span[rel='"+selected_value+"']");
                      to_show.show();
                      if(selected_value != "freetext") to_show.find("input:first").trigger("change");
                    }).trigger("change");
                    
                    $(".datepicker").datepicker(
                      $.extend({
                        showOn: "button",
                        buttonImage: "/assets/icons/calendar.png",
                        buttonImageOnly: true,
                        changeMonth: true,
                        changeYear: true,
                        onClose: function(dateText, inst) {
                          $(inst.input.context).trigger("blur");
                        }
                      }, $.datepicker.regional["#{locale}"])
                    );
                                      
                    $(".dates input.datepicker").bind("change", function() {
                      var source = $(this);
                      if(source.is(":visible") && source.val() != source.attr("placeholder")){
                        var v = source.siblings(".datepicker").andSelf().map(function() {
                          var t = $(this).nextAll(".time").first();
                          var r = this.value;
                          if(t.length) r = r + " " + t.val(); 
                          return r;
                        }).get().join(' - ');
                        source.closest(".dates").find("[rel='freetext'] input").val(v);
                      }
                    }).trigger("change");
                    
                    $(".time").bind("change", function() {
                      $(this).prevAll(".datepicker").first().trigger("change");
                    });
                  });
                HERECODE
                end.html_safe
              end
            end
  
          when "Meta::Department"
            h += widget_meta_terms_multiselect(meta_datum, meta_key)
  
          when "Copyright"
            h += meta_datum.hidden_field :value, :class => "copyright_value"
  ###          h += hidden_field_tag field_id, meta_datum.object.value.first, :class => "copyright_value"
  
            @copyright_all ||= Copyright.all # OPTIMIZE
            @copyright_roots ||= Copyright.roots
            value = meta_datum.object.deserialized_value.try(:first) # OPTIMIZE
            selected = @copyright_roots.detect{|s| (value and s.is_or_is_ancestor_of?(value)) }.try(:id)
            h += select_tag "options_root", options_from_collection_for_select(@copyright_roots, :id, :to_s, selected), :class => "options_root" 
  
            @copyright_roots.each do |s|
              next if s.leaf?
              grouped_options = s.children.collect do |t|
                                    if t.leaf?
                                      [nil, [[t.label, t.id]]]
                                    else
                                      [t.label, t.children.collect {|c| [c.label, c.id] }]
                                    end
                                end
              is_selected = (value and s.is_or_is_ancestor_of?(value))
              h += select_tag "options_#{s.id}", grouped_options_for_select(grouped_options, value.try(:id)), :class => "nested_options options_#{s.id}", :style => (is_selected ? nil : "display: none;")
            end
  
            @js_2 ||= false
            h += javascript_tag do
              @js_2 = true
              begin
              <<-HERECODE
                $(document).ready(function(){
                  var copyrights = {};
                  var custom_copyright_id;
                  $.each(#{@copyright_all.to_json}, function(i,item){
                    copyrights[item.id] = item;
                    if(item.is_custom) custom_copyright_id = item.id; 
                  });
                  
                  $("select.nested_options, select.options_root").change(function(event){
                    selected = copyrights[$(this).val()];
                    block = $(this).closest(".meta_data_block");
                    block.find(".copyright_value").val(selected.id);
                    if(!selected.is_custom){
                      block.find("[data-meta_key='copyright_usage'] textarea").val(selected.usage);
                      block.find("[data-meta_key='copyright_url'] textarea").val(selected.url);
                    }
                  });
                
                  $("select.options_root").change(function(event){
                    block = $(this).closest(".meta_data_block");
                    block.find(".nested_options").hide();
                    block.find(".options_" + selected.id).show().change();
  
                    usage = block.find("[data-meta_key='copyright_usage']");
                    if(selected.usage == null){
                      usage.hide();
                    }else{
                      usage.show();
                    }
                    url = block.find("[data-meta_key='copyright_url']");
                    if(selected.url == null){
                      url.hide();
                    }else{
                      url.show();
                    }
                  });
                  
                  $("[data-meta_key='copyright_usage'], [data-meta_key='copyright_url']").change(function(event){
                    block = $(this).closest(".meta_data_block");
                    block.find("select.options_root").val(custom_copyright_id).trigger('change');
                  });
  
                  //temp//doesn't work with generic nested meta_data// $("select.nested_options:visible, select.options_root").trigger('change');
                });
              HERECODE
              end.html_safe
            end unless @js_2
        end
  
      elsif definition.length_max and definition.length_max <= 255
        #tmp# h += meta_datum.text_field :value, :class => "value", :"data-required" => is_required
        h += text_field_tag "#{meta_datum.object_name}[value]", meta_datum.object.to_s, :class => "value", :"data-required" => is_required
        h += content_tag :span, :class => "with_actions" do
              link_to _("Übertragen auf andere Medien"), "#", :class => "hint"
             end if with_actions # TODO see _bulk_edit
      else
        #tmp# h += meta_datum.text_area :value, :"data-required" => is_required #, :rows => 2
        h += text_area_tag "#{meta_datum.object_name}[value]", meta_datum.object.to_s, :"data-required" => is_required, :rows => 2
      end
  
      @js_4 ||= false
      h += javascript_tag do
        @js_4 = true
        begin
        <<-HERECODE
          $(document).ready(function(){
              $("##{field_id}").focus();
          });
        HERECODE
        end.html_safe
      end if autofocus and !@js_4
  
      h
    end

    def description_toggler(definition)
      d = definition.description.try(:to_s)
      unless d.blank?
        r = link_to "?", "#", :class => "description_toggler"
        r += content_tag :span, :style => "display: none;", :class => "dialog hint" do
          auto_link(d, :all, :target => "_blank")
        end
      end
    end
    
  end
end
