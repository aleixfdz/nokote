require 'json'
require 'ostruct'
require 'minitest/autorun'
require_relative '../lib/nokote.rb'
require 'pathname'


class StaticTest < Minitest::Test
  Dir['test/static/*.nokote'].each do |template|
    Dir["#{template.gsub /\.nokote$/, ''}.*.html"].each do |html|
      res = Dir[html.gsub /html$/, 'res'][0]
      name = 'test_' + Pathname.new(html.gsub /\.html$/, '').basename.to_s
      define_method (name.gsub '.', '_') do
        parse_and_compare(template, html, res)
      end
    end
  end

  def parse_and_compare template, html, res
    out_data = OpenStruct.new
    err = ''
    out = Nokote::NokoteParser.parse_document (IO.read template), (IO.read html), out_data, err
    if res
      assert out, "not parsed valid document #{err}"
      res_output = IO.read res
      res_data = JSON.parse res_output, object_class: OpenStruct
      assert out_data == res_data, "invalid data generated #{out_data} #{res_data}"
    else
      assert !out, "parsed invalid document"
    end
  end
end
