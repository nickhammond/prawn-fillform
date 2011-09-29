# -*- encoding : utf-8 -*-
require 'prawn-fillform/version'
require 'open-uri'
OpenURI::Buffer::StringMax = 0

module Prawn

  module Fillform

    class Field
      include Prawn::Document::Internals

      def initialize(dictionary)
        @dictionary = dictionary
      end

      def description
        deref(@dictionary[:TU])
      end

      def rect
        deref(@dictionary[:Rect])
      end

      def name
        deref(@dictionary[:T]).to_sym
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
        deref(@dictionary[:V])
      end

      def default_value
        deref(@dictionary[:DV])
      end

      def flags
        deref(@dictionary[:Ff])
      end

    end

    class Text < Field

      def align
        case deref(@dictionary[:Q]).to_i
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
        deref(@dictionary[:MaxLen]).to_i
      end

      def font_size
        deref(@dictionary[:DA]).split(" ")[1].to_f
      end

      def font_style
        style = case deref(@dictionary[:DA]).split(" ")[0].split(",").last.to_s.downcase
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
        Prawn::Graphics::Color.rgb2hex(deref(@dictionary[:DA]).split(" ")[3..5].collect { |e| e.to_f * 255 }).to_s
      end

      def type
        :text
      end
    end

    class Button < Field
      def type
        :button
      end
    end

    class References
      include Prawn::Document::Internals
      def initialize(state)
        @state = state
        @refs = []
        collect!
      end

      def delete!
        @refs.each do |ref|
          ref[:acroform_fields].delete(ref[:field])
          deref(deref(ref[:page])[:Annots]).delete(ref[:field])
        end
      end

      protected
      def collect!

       root = deref(@state.store.root)
       acro_form = deref(root[:AcroForm])
       form_fields = deref(acro_form[:Fields])

        @state.pages.each_with_index do |page, i|
          form_fields.map do |ref|
            field_dict = deref(ref)
            reference = {}
            reference[:page] = field_dict[:P]
            reference[:field] = ref
            reference[:acroform_fields] = form_fields
            @refs << reference
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

      root = deref(state.store.root)
      acro_form = deref(root[:AcroForm])
      form_fields = deref(acro_form[:Fields])

      state.pages.each_with_index do |page, i|
        page_number = "page_#{i+1}".to_sym
        acroform[page_number] = []
        form_fields.map do |ref|
          dictionary = deref(ref)

          next unless deref(dictionary[:Type]) == :Annot and deref(dictionary[:Subtype]) == :Widget
          next unless (deref(dictionary[:FT]) == :Tx || deref(dictionary[:FT]) == :Btn)

          type = deref(dictionary[:FT]).to_sym
          case type
          when :Tx
            acroform[page_number] << Text.new(dictionary)
          when :Btn
            acroform[page_number] << Button.new(dictionary)
          end
        end
      end
      acroform
    end

    def fill_form_with(data={})

      acroform_fields.each do |page, fields|
        fields.each do |field|
          number = page.to_s.split("_").last.to_i
          go_to_page(number)
          value = data[page][field.name].fetch(:value) rescue nil
          options = data[page][field.name].fetch(:options) rescue nil
          options ||= {}

          if value
            value = value.to_s
            if field.type == :text
              fill_color options[:font_color] || field.font_color

              text_box value, :at => [field.x + 2, field.y - 1],
                                    :align => options[:align] || field.align,
                                    :width => options[:width] || field.width,
                                    :height => options[:height] || field.height,
                                    :valign => options[:valign] || :center,
                                    :size => options[:font_size] || field.font_size,
                                    :style => options[:font_style] || field.font_style
            elsif field.type == :button

              bounding_box([field.x, field.y], :width => field.width, :height => field.height) do
                if value =~ /http/
                  image open(value), :position => options[:position] || :center,
                                  :vposition => options[:vposition] || :center,
                                  :fit => options[:fit] || [field.width, field.height]
                else
                  image value, :position => options[:position] || :center,
                                  :vposition => options[:vposition] || :center,
                                  :fit => options[:fit] || [field.width, field.height]
                end

              end
            end
          end
        end
      end

      references = References.new(state)
      references.delete!

    end
  end
end

require 'prawn/document'
Prawn::Document.send(:include, Prawn::Fillform)

