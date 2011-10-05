# Prawn/Fillform: Fill Text and Images through Acroform Fields

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
data[:page_1][:lastname] = { :value => "Mustermann" }
data[:page_1][:photo] = { :value => "test.jpg" }

# Create a PDF file with predefined data Fields
Prawn::Document.generate "output.pdf", :template => "template.pdf"  do |pdf|
  pdf.fill_form_with(data)
end
```

Take a look in `examples` folder

