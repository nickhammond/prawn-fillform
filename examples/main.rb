#!/usr/bin/env ruby
# -*- encoding : utf-8 -*-

$LOAD_PATH << File.expand_path('../../lib/', __FILE__)

require 'prawn'
require 'prawn-fillform'

data = {}
data[:page_1] = {}
data[:page_1][:firstname] = { :value => "Max" }
data[:page_1][:photo] = { :value => "../data/test.jpg", :options => { fill: true } }
# Page number optional, substitute lastname var in all pages
data[:lastname] = { :value => "Mustermann" }
data[:checked] = { :value => "true" }
data[:comb] = { :value => "123456", :options => { :font_size => 20 } }
data[:comb_too_small] = { :value => "123456789" }


Prawn::Document.generate "../data/output.pdf", :template => "../data/template.pdf"  do |pdf|
  pdf.fill_form_with(data, allow_comb_overflow: true)
end

