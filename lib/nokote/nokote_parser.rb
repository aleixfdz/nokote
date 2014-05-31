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
    template = Nokogiri::HTML::DocumentFragment.parse template
    doc = Nokogiri::HTML::DocumentFragment.parse doc
    begin
      match_node template, doc
    rescue NotokeParserError => ex
      # error_message.replace "#{ex.to_s}\n  " + ex.backtrace.join("\n  ") if error_message
      error_message.replace ex.to_s if error_message
      return false
    end
  end


 private
  def init_encode
    Base32.table = 'abcdefghijklmnopqrstuvwxyzABCDEF'
  end

  def decode string
    Base32.decode string
  end

  def encode string
    (Base32.encode string).gsub /[=]+$/, ''
  end


  def generate_tag doc
    tag = encode SecureRandom.hex(32)
    (doc.include? tag) ? (generate_tag doc) : tag
  end


  def pack i
    dl = dtag.length
    pos = i.enum_for(:scan, @dtag).map {Regexp.last_match.begin(0)}
    assert (pos.size%2 == 0), "invalid tag"
    next_pos = 0
    o = ''
    pos.each_slice(2).each do |b,e|
      o += i[next_pos..b-next_pos-1]
      o += tag + (encode i[b+dl..e-1]) + tag
      next_pos = e + dl
    end
    o += i[next_pos..-1]
  end

  def unpack str
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

  def match_node t, d
    # basic check stuff
    set_context t, d
    puts "#{t.class} : #{t} vs #{d}"
    return true if t == nil and d == nil
    assert (t != nil or d != nil), "unexpected end of file"
    assert (t.class == d.class), "different class"  # TODO add support insert code &&!

    # special match anything inside the tag <&&#tag!></&&#tag!>
    return eval_code d.content, "error match #tag!" if (unpack t.name) == '#tag!'

    # attributes
    ta = t.attribute_nodes.sort
    da = d.attribute_nodes.sort
    (ta.zip da).all? {|dt| match_node *dt}
    # retrieve context
    set_context t, d

    # special match anything inside the tag <&&#tag></&&#tag> after having check
    # the attributes
    return eval_code d.content, "error match #tag!" if (unpack t.name) == '#tag'

    # name
    match_string t.name, d.name

    # content if this is a text element
    match_string t.content, d.content if t.class == Nokogiri::XML::Text

    # children
    assert (t.children.zip d.children).all? {|dt| match_node *dt}, "children"

    # continue with the sibling
    match_node t.next_sibling, d.next_sibling
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
