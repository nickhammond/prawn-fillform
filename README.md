# Prawn/Fillform: Fill Text and Images through Acroform Fields

### Sorry, I have unfortunately no time to maintain the code. You can use the code for any purpose.

## Install

```bash
$ gem install prawn-fillform
```

## Usage
Create a PDF form with Scribus, Adobe Products or something else. I have only tested this with Scribus.
Currently only text fields and buttons are supported. Buttons are replaced by images.


```ruby
require 'prawn-fillform'

data = {}
data[:page_1] = {}
data[:page_1][:firstname] = { :value => "Max" }
data[:page_1][:photo] = { :value => "test.jpg" }

# Page number optional, substitute lastname var in all pages, thanks to hoverlover
data[:lastname] = { :value => "Mustermann" }

# Create a PDF file with predefined data Fields
Prawn::Document.generate "output.pdf", :template => "template.pdf"  do |pdf|
  pdf.fill_form_with(data)
end
```

Take a look in `examples` folder

## Thanks to netinlet for fix field placement bug

I was having issue with the form field placement (see https://github.com/moessimple/prawn-fillform/issues/1)
Scribus and Adobe Acrobat don't open pdf's in the same way so the formatting comes out differently. Much like
opening a Word document in OpenOffice can some render with funny formatting.

Added the ability to set :x_offset and :y_offset at the class level and on a per form basis.

#Class Methods
```ruby
Prawn::Document.set_fillform_xy_offset(x_offset, y_offset)

Prawn::Document.use_adobe_xy_offsets! # Your mileage may vary! Defaults to x_offset:2, y_offset:-40

Prawn::Document.fillform_x_offset

Prawn::Document.fillform_y_offset
```

#And on a per-form basis

See the :options param below

```ruby
require 'prawn-fillform'

data = {}
data[:page_1] = {}
data[:page_1][:firstname] = { :value => "Max", :options => {:x_offset => 2, :y_offset => -40} }
data[:page_1][:lastname] = { :value => "Mustermann" }
data[:page_1][:photo] = { :value => "test.jpg" }

# Create a PDF file with predefined data Fields
Prawn::Document.generate "output.pdf", :template => "template.pdf"  do |pdf|
  pdf.fill_form_with(data)
end
```










