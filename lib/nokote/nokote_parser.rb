require 'base32'
require 'securerandom'
require 'nokogiri'


module Nokote


class NokoteParser
 public
  def initialize template, dtag = '&&', str_cmp = nil
    @plain_template = template
    @dtag = dtag
    # TODO use str_cmp depending on name, value, content, and passing context...
    init_encode
  end

  def parse doc, data = nil, error_message = nil, err = nil
    @err = err ? err : STDERR
    @data = data
    @tag = generate_tag doc
    template = pack @plain_template
    puts @plain_template
    puts template
    template = html_parse template
    puts template.content
    doc = html_parse doc
    begin
      match_node template, doc, 'document'
    rescue NotokeParserError => ex
      error_message.replace "#{ex.to_s}\n  " + ex.backtrace.join("\n  ") if error_message
      # error_message.replace ex.to_s if error_message
      return false
    end
  end


 private
  def html_parse doc
    doc = Nokogiri::HTML::DocumentFragment.parse doc
    normalize doc
    doc
  end

  # all element has at least one children
  # every children that is not a Text has the previous and next siblings are Text
  def normalize node
    # this code works because Text nodes are merged whether it is possible
    node.add_child (new_empty_node node) if node.children.empty?
    prev_is_text = false
    node.children.each do |c|
      c.add_previous_sibling (new_empty_node node)
      normalize c
      c.add_next_sibling (new_empty_node node)
    end
  end
  def new_empty_node node
    Nokogiri::XML::Text.new '', node.document
  end



  def init_encode
    Base32.table = 'abcdefghijklmnopqrstuvwxyzABCDEF'
  end

  def decode string
    Base32.decode (decode2 string)
  end

  def encode string
    encode2 ((Base32.encode string).gsub /[=]+$/, '')
  end

  def encode2 string
    s = string
    ['z','A','B','C','D','E','F'].each {|c| s = s.gsub(c, 'z'+c.downcase)}
    s
  end

  def decode2 string
    s = string
    s = s.gsub /z(.)/, '$\1'
    ['z','A','B','C','D','E','F'].each {|c| s = s.gsub('$'+c.downcase, c)}
    s
  end

  def generate_tag doc
    tag = encode SecureRandom.hex(8)
    (doc.include? tag) ? (generate_tag doc) : tag
  end


  def pack i
    dl = dtag.length
    pos = i.enum_for(:scan, @dtag).map {Regexp.last_match.begin(0)}
    assert (pos.size%2 == 0), "invalid tag"
    next_pos = 0
    o = ''
    puts o
    pos.each_slice(2).each do |b,e|
      o += i[next_pos..b-1]
      puts o
      o += tag + (encode i[b+dl..e-1]) + tag
      puts o
      next_pos = e + dl
    end
    o += i[next_pos..-1]
    puts o
    o
  end

  def unpack str
    # TODO what a empty unpacked is depends on the context
    return nil if !str.start_with? tag
    str = str[tag.length..-1]
    return nil if !str.end_with? tag
    str = str[0..-tag.length-1]
    str.empty? ? '/.*/' : (decode str)
  end


  def set_context t, d
    @tcur = t if t.class <= Nokogiri::XML::Node
    @dcur = d if d.class <= Nokogiri::XML::Node
  end

  def match_nodea t, d
    match_node t, d, 'attr'
  end
  def match_nodec t, d
    match_node t, d, 'child'
  end
  def match_node t, d, s = nil
    # basic check stuff
    set_context t, d
    puts "#{s}> #{t.class} : #{t} vs #{d}"
    return true if t == nil and d == nil
    assert (t != nil or d != nil), "unexpected end of file"
    assert (t.class == d.class), "different class"  # TODO add support insert code &&!

    # special match anything inside the tag <&&#tag!></&&#tag!>
    # return eval_code d.content, "error match #tag!" if (unpack t.name) == '#tag!'

    # attributes
    ta = t.attribute_nodes
    da = d.attribute_nodes
    (zip_attributes ta, da).all? {|dt| match_nodea *dt}
    # retrieve context
    set_context t, d

    # the attributes
    # return eval_code d.content, "error match #tag!" if (unpack t.name) == '#tag'

    # name
    match_string t.name, d.name

    # content if this is a text element
    match_string t.content, d.content if t.class == Nokogiri::XML::Text

    # children
    assert (t.children.zip d.children).all? {|dt| match_nodec *dt}
  end

  def zip_attributes ta, da
    # TODO deal with repeated attributes
    ta = ta.sort
    da = da.sort

    open = ta.any? {|a| (unpack a.name) == '#open' && a.value == 'true'}
    optional = ta.map {|a| (unpack a.name) == '#optional' ? (a.value.split ' ') : []}.flatten
    ignore = ta.map {|a| (unpack a.name) == '#ignore' ? (a.value.split ' ') : []}.flatten
    ta.reject! {|a| ['#open', '#optional', '#ignore'].include? (unpack a.name)}
    puts "open #{open}, optional #{optional}, ignore #{ignore}"

    ztd = []
    ta.each do |t|
      d = da.find {|a| a.name == t.name}
      if d == nil
        if !optional.include? t.name
          assert! "not found attribute #{t.name}"
        end
      else
        da.delete_at (da.index d)
        ztd << [t, d]
      end
    end

    puts "#{open}, #{da.all? {|a| ignore.include? a.name}}, wat #{da}"

    assert (open || da.all? {|a| ignore.include? a.name}), "found unknown attribute"
    puts "ztd #{ztd}, ignored #{da}"
    ztd
  end

  def match_string t, d
    code = unpack t
    if code
      eval_code code, d
    else
      string_comparer t, d
    end
  end

  def eval_code code, node
    if code[0] == '/' and code[-1] == '/'
      re = Regexp.new code[1..-2]
      assert (re.match node), "regexp failed"
    else
      puts code
      puts node
      assert (eval code, (default_binding node)), "code evaluation fail"
    end
  end

  def default_binding node
    @node = node
    get_binding self
  end

  def get_binding tp
    return binding
  end


  def tag
    @tag
  end

  def dtag
    @dtag
  end



 public
  def data
    @data
  end

  def node
    @node
  end

  def string_comparer s0, s1
    assert (s0 == s1), "string comparer failed"
  end


  def debug str
    @err.puts str
  end

  def assert! msg = nil
    assert false, msg
  end

  class NotokeParserError < Exception
  end

  def assert cond, msg = nil
    # TODO print the attributes in a better way
    # TODO improve track
    # TODO unpack
    raise NotokeParserError, "error at template:#{@tcur.line} document:#{@dcur.line} #{msg}
  template_node: #{@tcur}
  document_node: #{@dcur}" if !cond
    true
  end
end


end
