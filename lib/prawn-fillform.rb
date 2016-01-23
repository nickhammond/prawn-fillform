# -*- encoding : utf-8 -*-
require 'prawn-fillform/version'
require 'open-uri'

OpenURI::Buffer.send :remove_const, 'StringMax' if OpenURI::Buffer.const_defined?('StringMax')
OpenURI::Buffer.const_set 'StringMax', 0

module Prawn

  module Fillform

    FLAG_REQUIRED       =  2.freeze
    FLAG_NO_SPELLCHECK  = 23.freeze
    FLAG_NO_SCROLL      = 24.freeze
    FLAG_COMB           = 25.freeze

    class Field
      include Prawn::Document::Internals

      def initialize(dictionary)
        @dictionary = dictionary
      end

      def description
        get_dict_item(:TU)
      end

      def rect
        get_dict_item(:Rect)
      end

      def name
        get_dict_item(:T).to_sym
      end

      def x
        rect[0]
      end

      def y
        rect[3]
      end

      def width
        rect[2] - rect[0]
      end

      def height
        rect[3] - rect[1]
      end

      def value
        get_dict_item(:V)
      end

      def default_value
        get_dict_item(:DV)
      end

      def flags
        get_dict_item(:Ff) || 0
      end

      def has_flag?(num)
        # We're doing a bit of bit-magic here, essentially the flags for the field is a bitmask
        # We create a dynamic bitmask for the correct position and check if that bit is set in the flags.
        pos = (num-1)
        bitmask = (1 << pos)
        ((flags & bitmask) >> pos) == 1
      end

      def required?
        has_flag?(FLAG_REQUIRED)
      end

    private
      def get_dict_item(key)
        if @dictionary[key]
          deref(@dictionary[key])
        else
          parent = deref(@dictionary[:Parent])
          deref(parent[key]) if parent
        end
      end

    end

    class Text < Field

      def align
        case get_dict_item(:Q).to_i
        when 0
          :left
        when 1
          :center
        when 2
          :right
        else
          :left
        end
      end

      def max_length
        get_dict_item(:MaxLen).to_i
      end

      def font_size
        return 12.0 unless get_dict_item(:DA)
        get_dict_item(:DA).split(" ")[1].to_f
      end

      def font_style
        return :normal unless get_dict_item(:DA)

        style = case get_dict_item(:DA).split(" ")[0].split(",").last.to_s.downcase
        when "bold" then :bold
        when "italic" then :italic
        when "bold_italic" then :bold_italic
        when "normal" then :normal
        else
          :normal
        end
        style
      end

      def font_color
        return "0000" unless get_dict_item(:DA)
        Prawn::Graphics::Color.rgb2hex(get_dict_item(:DA).split(" ")[3..5].collect { |e| e.to_f * 255 }).to_s
      end

      DEFAULT_PDF_FONT_FACES = {
        Cour: 'Courier',
        Helv: 'Helvetica',
        TiRo: 'Times-Roman'
      }

      def font_face
        short_font_name = get_dict_item(:DA).split(" ")[0][1..-1].to_sym
        if embedded_fonts
          deref(embedded_fonts[short_font_name])[:BaseFont].to_s
        else
          DEFAULT_PDF_FONT_FACES[short_font_name]
        end
      end

      def embedded_fonts
        ap = get_dict_item(:AP)
        return nil if ap.nil?
        deref(deref(ap[:N])[:Resources][:Font])
      end

      def type
        :text
      end

      def no_spellcheck?
        has_flag?(FLAG_NO_SPELLCHECK)
      end

      def no_scroll?
        has_flag?(FLAG_NO_SCROLL)
      end

      def comb?
        has_flag?(FLAG_COMB)
      end
    end

    class Button < Field
      def type
        :button
      end
    end

    class Checkbox < Field
      def type
        :checkbox
      end
    end

    class References
      include Prawn::Document::Internals
      def initialize(state)
        @state = state
        @refs = []
        @refs_2 = []
        collect!
      end

      def delete!
        @refs.each do |ref|
          ref[:annots].delete(ref[:ref])
        end
        @refs_2.each do |ref|
          ref[:acroform_fields].delete(ref[:field])
        end
      end

      protected
      def collect!
        @state.pages.each_with_index do |page, i|
          annots = deref(page.dictionary.data[:Annots])
          if annots
            annots.map do |ref|
              reference = {}
              reference[:ref] = ref
              reference[:annots] = annots
              @refs << reference
            end
          end
        end

        root = deref(@state.store.root)
        acro_form = deref(root[:AcroForm])
        return unless acro_form
        form_fields = deref(acro_form[:Fields])

        @state.pages.each_with_index do |page, i|
          form_fields.map do |ref|
            reference = {}
            reference[:field] = ref
            reference[:acroform_fields] = form_fields
            @refs_2 << reference
          end
        end
      end
    end

    def acroform_field_names
      result = []
      acroform_fields.each do |page, fields|
        fields.each do |field|
          result << field.name
        end
      end
      result
    end

    def acroform_fields
      acroform = {}
      state.pages.each_with_index do |page, i|
        page_number = "page_#{i+1}".to_sym
        acroform[page_number] = acroform_fields_for_page(page)
      end
      acroform
    end

    def acroform_fields_for_page(page)
      annots = deref(page.dictionary.data[:Annots])
      page_fields = []
      if annots
        # Support annotations with parents
        annots.flat_map do |ref|
          dictionary = deref(ref)
          if dictionary[:Parent]
            deref(deref(dictionary[:Parent])[:Kids]).map { |kid| deref(kid) }.select { |kid| kid[:P] == page.dictionary }
          else
            [dictionary]
          end
        end.each do |dictionary|
          next unless deref(dictionary[:Type]) == :Annot and deref(dictionary[:Subtype]) == :Widget

          if dictionary[:Parent]
            type = deref(dictionary[:Parent])[:FT]
          else
            type = deref(dictionary[:FT])
          end
          next unless (type == :Sig || type == :Tx || type == :Btn)

          case type
          when :Tx
            page_fields << Text.new(dictionary)
          when :Btn
            if deref(dictionary[:AP]).has_key? :D
              page_fields << Checkbox.new(dictionary)
            else
              page_fields << Button.new(dictionary)
            end
          when :Sig
            page_fields << Button.new(dictionary)
          end
        end
      end

      page_fields
    end

    def fetch_field_attribute(data, page, field_name, attribute)
      page_number = page.to_s.split('_').last.to_i + 1
      page_key = "page_#{page_number}".to_sym
      value = data[page_key][field_name].fetch(attribute) rescue nil
      if value.nil?
        value = data[field_name].fetch(attribute) rescue nil
      end
      value
    end

    # Found by manual adjustment until it looked right.
    FILLFORM_X_OFFSET = -34
    FILLFORM_Y_OFFSET = -38

    def fill_form_page_with(data, x_offset: FILLFORM_X_OFFSET, y_offset: FILLFORM_Y_OFFSET, allow_comb_overflow: false)
      acroform_fields_for_page(page).each do |field|
        value = fetch_field_attribute(data, page, field.name, :value)
        if value
          options = fetch_field_attribute(data, page, field.name, :options) || {}
          value = value.to_s
          x_offset = options[:x_offset] || x_offset
          y_offset = options[:y_offset] || y_offset
          x_position = field.x + x_offset
          y_position = field.y + y_offset
          width = options[:width] || field.width
          height = options[:height] || field.height

          if field.type == :text
            fill_color options[:font_color] || field.font_color
            font options[:font_face] || field.font_face

            # Default to the document font size if the field size is 0
            size = options[:font_size] || ((size = field.font_size) > 0.0 ? size : font_size)
            style = options[:font_style] || field.font_style

            # Check if the comb field can be drawn
            draw_comb_field = field.comb? && field.no_spellcheck? && field.no_scroll?
            if draw_comb_field && value.length > field.max_length
              if allow_comb_overflow
                # Fallback to drawing a text box
                draw_comb_field = false
              else
                raise Prawn::Errors::CannotFit
              end
            end

            if draw_comb_field
              x_spacing = width / field.max_length
              value.split('').each_with_index do |c, index|
                text_box c, :at => [x_position + x_spacing * index, y_position],
                  :align => :center,
                  :width => x_spacing,
                  :height => height,
                  :valign => options[:valign] || :center,
                  :size => size,
                  :style => style,
                  :overflow => :strink_to_fit
              end
            else
              text_box value, :at => [x_position, y_position],
                :align => options[:align] || field.align,
                :width => width,
                :height => height,
                :valign => options[:valign] || :center,
                :size => size,
                :style => style
            end
          elsif field.type == :checkbox
            is_yes = (v = value.downcase) == "yes" || v == "1" || v == "true"
            if is_yes
              stroke do
                # Determine relative co-ordinates based on current bounding box
                check_left = field.x - bounds.absolute_left
                check_bottom = field.y - field.height - bounds.absolute_bottom

                # Draw check mark
                line check_left, check_bottom, check_left + field.width, check_bottom + field.height
                line check_left + field.width, check_bottom, check_left, check_bottom + field.height
              end
            end
          elsif field.type == :button
            bounding_box([x_position, y_position], :width => width, :height => height) do
              image_options = {
                :position => options[:position] || :center,
                :vposition => options[:vposition] || :center,
              }
              if options[:fill]
                image_options[:fit] = [width, height]
              else
                image_options[:height] = height
              end
              if value =~ /http/
                image open(value), image_options
              else
                image value, image_options
              end
            end
          end
        end
      end
    end

    def fill_form_with(data, x_offset: FILLFORM_X_OFFSET, y_offset: FILLFORM_Y_OFFSET, allow_comb_overflow: false)
      state.pages.each_index do |number|
        go_to_page(number)
        fill_form_page_with(data, x_offset: x_offset, y_offset: y_offset, allow_comb_overflow: allow_comb_overflow)
      end

      remove_form_fields
    end

    def remove_form_fields
      references = References.new(state)
      references.delete!
    end
  end
end

require 'prawn/document'
Prawn::Document.send(:include, Prawn::Fillform)
