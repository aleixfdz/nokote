require 'json'
require 'ostruct'
require 'minitest/autorun'
require_relative '../lib/nokote.rb'
require 'pathname'


class StaticTest < Minitest::Test
  begin
    Dir['test/grammar/*.nokote'].each do |template|
      tn = template.gsub /\.nokote$/, ''
      Dir["#{tn}.*.html"].each do |html|
        first_rule = (html[tn.length+1..-1].split '.').first
        res = Dir[html.gsub /html$/, 'res'][0]
        name = 'test_g_' + Pathname.new(html.gsub /\.html$/, '').basename.to_s
        define_method (name.gsub '.', '_') do
          parse_and_compare_g(template, first_rule, html, res)
        end
      end
    end

    Dir['test/template/*.nokote'].each do |template|
      Dir["#{template.gsub /\.nokote$/, ''}.*.html"].each do |html|
        res = Dir[html.gsub /html$/, 'res'][0]
        name = 'test_t_' + Pathname.new(html.gsub /\.html$/, '').basename.to_s
        define_method (name.gsub '.', '_') do
          parse_and_compare_t(template, html, res)
        end
      end
    end
  end

  def parse_and_compare_g grammar, first_rule, html, res
    out_data = OpenStruct.new
    err = ''
    out = Nokote::NokoteParser.load_grammar_and_parse_document grammar, first_rule, (IO.read html), out_data, err
    if res
      assert out, "not parsed valid grammar #{err}"
      res_output = IO.read res
      res_data = JSON.parse res_output, object_class: OpenStruct
      assert out_data == res_data, "invalid data generated #{out_data} #{res_data}"
    else
      assert !out, "parsed invalid document"
    end
  end
  def parse_and_compare_t template, html, res
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
