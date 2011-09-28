require 'prawn-fillform/version'

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

      def font_size
        deref(@dictionary[:DA]).split(" ")[1].to_f
      end

      def font_color
        Prawn::Graphics::Color.rgb2hex(deref(@dictionary[:DA]).split(" ")[3..5].collect { |e| e.to_f * 255 }).to_s
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
          ref[:annots].delete(ref[:ref])
        end
      end

      protected
      def collect!
        @state.pages.each_with_index do |page, i|
          @annots = deref(page.dictionary.data[:Annots])
          @annots.map do |ref|
            reference = {}
            reference[:ref] = ref
            reference[:annots] = @annots
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
      state.pages.each_with_index do |page, i|
        annots = deref(page.dictionary.data[:Annots])
        page_number = "page_#{i+1}".to_sym
        acroform[page_number] = []
        acroform[page_number] = []
        annots.map do |ref|
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
            if field.type == :text
              fill_color options[:font_color] || field.font_color
              text_box value, :at => [field.x + 2, field.y - 1],
                                    :align => options[:align] || field.align,
                                    :width => options[:width] || field.width,
                                    :height => options[:height] || field.height,
                                    :valign => options[:valign] || :center,
                                    :size => options[:font_size] || field.font_size
            elsif field.type == :button
              image value, :at => [field.x + 2, field.y - 1],
                                 :position =>  options[:position] || :center,
                                 :vposition => options[:vposition] || :center,
                                 :fit => options[:fit] || [field.width, field.height]
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

