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

    end

    class Text < Field

      def align
        case deref(@dictionary[:Q])
        when 0
          :left
        when 1
          :center
        when 2
          :right
        end
      end

      def max_length
        deref(@dictionary[:MaxLen])
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
          value = data[page][field.name] rescue nil

          if value
            if field.instance_of? Prawn::Fillform::Text
              text_box value, :at => [field.x, field.y],
                                    :align => field.align,
                                    :width => field.width,
                                    :height => field.height,
                                    :valign => :center
            elsif field.instance_of? Prawn::Fillform::Button
              image value, :at => [field.x, field.y],
                                 :position => :center,
                                 :vposition => :center,
                                 :fit => [field.width, field.height]
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

