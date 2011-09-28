# -*- encoding : utf-8 -*-
require 'rubygems'

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib')

require 'prawn'
require 'prawn/fillform'


data = {}
data[:page_1] = {}
data[:page_1][:firstname] = "Max"
data[:page_1][:lastname] = "Mustermann"
data[:page_1][:photo] = "../data/test.jpg"


Prawn::Document.generate "../data/output.pdf", :template => "../data/template.pdf"  do |pdf|
  pdf.fill_form_with(data)
end

