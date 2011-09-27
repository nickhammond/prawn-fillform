require 'prawn-fillform/version'

module Prawn
  module Fillform

    def fill_form_with(data={})

      1.upto(acroform_number_of_pages).each do |page|


        page_number = "page_#{page}".to_sym
        fields = acroform_fields_for(page_number)
        fields.each do |field|
          x = field[:x]
          y = field[:y]
          value = data[page_number][field.fetch(:name)] rescue nil
          go_to_page(field[:page_number])

          if field[:type] == :image
            image value, :at => [x, y], :position => :center, :vposition => :center, :fit => [field[:width], field[:height]] if value
          else
            text_box value, :at => [x, y], :align => field[:align],
                            :width => field[:width], :height => field[:height],
                            :valign => :center, :align => :left, :single_line => !field[:multi_line], :size => field[:size] if value
          end
        end
      end

      # delete acroform references
      acroform_specifications.last.each do |reference|
        reference[:acroform_fields].delete(reference[:field])
      end
    end


    private
      def acroform_fields_for(page)
        acroform_specifications.first.fetch(page).fetch(:fields)
      end

      def acroform_number_of_pages
        acroform_specifications.first.keys.length
      end

      def acroform_field_info(form_fields, field_ref, page)

        field_dict = deref(field_ref)

        field = {}

        field_type = deref(field_dict[:FT])

        field[:name] = deref(field_dict[:T]).to_sym
        field[:type] = field_type == :Tx ? :text : :image
        field[:rect] = deref(field_dict[:Rect])
        field[:x] = field[:rect][0]
        field[:y] = field[:rect][3]
        field[:width] = field[:rect][2] - field[:rect][0]
        field[:height] = field[:rect][3] - field[:rect][1]
        field[:page_number] = page

        if field[:type] == :text
          field[:description] = deref(field_dict[:TU])
          field[:default_value] = deref(field_dict[:DV])
          field[:value] = deref(field_dict[:V])
          field[:size] = deref(field_dict[:DA]).split(" ")[1].to_i
          field[:style] = deref(field_dict[:DA].split(" ")[0])
          field[:align] = case deref(field_dict[:Q])
          when 0 then :left
          when 2 then :center
          when 4 then :right
          end
          field[:max_length] = deref(field_dict[:MaxLen])
          field[:multi_line] = deref(field_dict[:Ff]).to_i > 0 ? :true : :false
          field[:border_width] = deref(field_dict[:BS]).fetch(:W, nil) if deref(field_dict[:BS])
          field[:border_style] = deref(field_dict[:BS]).fetch(:S, nil) if deref(field_dict[:BS])
          field[:border_color] = deref(field_dict[:MK]).fetch(:BC, nil) if deref(field_dict[:MK])
          field[:background_color] = deref(field_dict[:MK]).fetch(:BG, nil) if deref(field_dict[:MK])
        end

        field

      end

      def acroform_specifications

        specifications = {}
        references = []

        state.pages.each_with_index do |page, i|
          form_fields = deref(page.dictionary.data[:Annots])

          page_number = "page_#{i+1}".to_sym
          specifications[page_number] = {}
          specifications[page_number][:fields] = []

          form_fields.map do |field_ref|
            field_dict = deref(field_ref)
            next unless deref(field_dict[:Type]) == :Annot and deref(field_dict[:Subtype]) == :Widget
            next unless (deref(field_dict[:FT]) == :Tx || deref(field_dict[:FT]) == :Btn)

            field = acroform_field_info(form_fields, field_ref, i+1)
            specifications[page_number][:fields] << field

            reference = {}
            reference[:field] = field_ref
            reference[:acroform_fields] = form_fields
            references << reference
          end
        end
        [specifications, references]
      end

    end
end

require 'prawn/document'
Prawn::Document.send(:include, Prawn::Fillform)

