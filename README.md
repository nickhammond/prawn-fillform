# Prawn/Fillform: Fill Text and Images through Acroform Fields

## Install

```bash
$ gem install prawn-fillform
```

## Usage

```ruby
require 'prawn-fillform'

data = {}
data[:page_1] = {}
data[:page_1][:firstname] = "Max"
data[:page_1][:lastname] = "Mustermann"
data[:page_1][:photo] = "test.jpg"

# Create a PDF file with predefined data Fields
Prawn::Document.generate "output.pdf", :template => "template.pdf"  do |pdf|
  pdf.fill_form_with(data)
end
```

Take a look in `examples` folder

