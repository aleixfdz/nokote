require 'base32'
require 'securerandom'
require 'nokogiri'
require_relative 'nokote_grammar.rb'


# TODO add debug mode please

module Nokote


class NokoteParser
 public
=begin
  end

  def parse doc, rule, data = nil, error_message = nil, err = nil
    @data = data
    @tag = generate_tag doc
    @templates = Hash[@plain_templates.map {|id,t| [id, html_parse t]}
    doc = html_parse doc
    resolve rule, doc
  end

  def resolve rule_id, node
    return match_template rule_id[1..-1], node if rule_id[0] == '#'
    rule = @rules[id]
    
    case rule
    when Nokote::Repeat
    when Nokote::Find
    when Nokote::Match
    when Nokote::Optional
    else
      raise ArgumentError 'not found rule #{rule}'
    end
  end

  def match_template template, node
    template = @templates
    raise ArgumentError 'not found template #{template}' if !template
    begin
      match_node template, node
    rescue NotokeParserError => ex
      false
    end
  end
=end


  # TODO change all this shit
  def self.init_encode
    Base32.table = 'abcdefghijklmnopqrstuvwxyzABCDEF'
  end

  def self.parse_document template, doc, data = nil, error_message = nil, template_tag = '&&'
    init_encode
    tag = generate_tag doc
    parser = self.new({'0' => '#t'}, {'t' => template}, tag, template_tag)
    parser.parse_doc '0', doc, data, error_message
  end

  def initialize rules, templates, secure_tag, template_tag = '&&'
    @dtag = template_tag
    @tag = secure_tag
    raise ArgumentError, "invalid rule name" if rules.keys.any? {|n| n[0] == '#'}
    @templates = {}
    templates.each {|k,v| @templates[k] = self.class.html_parse (self.class.pack v, tag, dtag)}
    #@templates = Hash[*templates.map {|k,v| [k, self.class.html_parse (self.class.pack v, tag, dtag)]}.flatten]
    raise ArgumentError, "invalid templates #{templates}" if !@templates.all?
    @rules = rules
    @backtrack = []
    puts "#{@rules}\n#{@templates}"
  end

  def parse_doc rt, doc, data = nil, error_message = nil
    node = self.class.html_parse doc
    parse rt, node.children[0], data, error_message
  end
  def parse rt, node, data = nil, error_message = nil
    @data = data
    resolve rt, node
  end

=begin
  # return false if node cannot be parsed by template, otherwise return the
  # first not parsed node
  def match node, data = nil, error_message = nil
    @data = data
    begin
      match_node @template, node, 'document'
    rescue NotokeParserError => ex
      error_message.replace "#{ex.to_s}\n  " + ex.backtrace.join("\n  ") if error_message
      return false
    end
  end
=end

 private
  def resolve rt, node
    res = resolve_impl rt, node
    backtrack! while !res and backtrack?
    res
  end

  def resolve_impl rt, node
    if rt[0] == '#'
      template = @templates[rt[1..-1]]
      raise ArgumentError 'not found template #{rt[1..-1]}' if template == nil
      match_template template, node
    else
      rule = @rules[rt]
      raise ArgumentError 'not found rule #{rt}' if rule == nil
      resolve_rule rule, node
    end
  end

  def add_backtrack cc, debug_message = nil
   @backtrack.push cc 
  end

  def backtrack?
    !@backtrack.empty?
  end

  def backtrack!
    backtrack.pop.call
  end

  def resolve_rule rule, node
    puts "apply #{rule} at #{node}"
    case rule
    when Optional
      rules = rule.rules.dup
      return true if rules.empty?  # TODO warn about empty?
      context = nil
      callcc {|cc| context = cc}
      return false if rules.empty?
      add_backtrack context, "#{rule} : #{rules}"
      resolve_impl rules.shift, node
    when Concat
      rule.rules.each do |r_id|
        node = resolve_impl r_id, node
        return false if node == false
      end
      node
    when Repeat
      (0..rule.min-1).each do
        node = resolve_impl rule.rule, node
        return false if node == false
      end
      nodes = [node]
      (0..rule.max-1).each do  # TODO max -1 is infinity...
        node = resolve_impl rule.rule, node
        break if node == false
        nodes.push node
        # TODO warn if no consuming?
      end
      context = nil
      callcc {|cc| context = cc}
      return false if nodes.empty?
      add_backtrack context, "#{rule} : #{nodes}"
      nodes.pop
    when OnCandidates
      nodes = rule.generator.call node
      return false if nodes.empty?
      context = nil
      callcc {|cc| context = cc}
      return false if nodes.empty?
      add_backtrack context, "#{rule} : #{nodes}"
      resolve_impl rule.rule, nodes.shift
    when Empty
      node
    when FinalNode
      node == nil ? nil : false
    when String
      resolve_impl rule, node
    else
      raise ArgumentError, "invalid rule #{rule}"
      return false
    end
  end

  def match_template template, node
    puts "match #{template} at #{node}"
    begin
      match_node template.children[0], node
    rescue NotokeParserError => ex
      false
    end
  end


  def self.html_parse doc
    doc = Nokogiri::HTML::DocumentFragment.parse doc
    normalize doc
    doc
  end

  # all element has at least one children
  # every children that is not a Text has the previous and next siblings are Text
  def self.normalize node
    # this code works because Text nodes are merged whether it is possible
    node.add_child (new_empty_node node) if node.children.empty?
    prev_is_text = false
    node.children.each do |c|
      c.add_previous_sibling (new_empty_node node)
      normalize c
      c.add_next_sibling (new_empty_node node)
    end
  end

  def self.new_empty_node node
    Nokogiri::XML::Text.new '', node.document
  end




  # TODO change all this shit
  def self.generate_tag doc
    tag = encode SecureRandom.hex(8)
    (doc.include? tag) ? (generate_tag doc) : tag
  end

  def self.decode string
    Base32.decode (decode2 string)
  end

  def self.encode string
    encode2 ((Base32.encode string).gsub /[=]+$/, '')
  end

  def self.encode2 string
    s = string
    ['z','A','B','C','D','E','F'].each {|c| s = s.gsub(c, 'z'+c.downcase)}
    s
  end

  def self.decode2 string
    s = string
    s = s.gsub /z(.)/, '$\1'
    ['z','A','B','C','D','E','F'].each {|c| s = s.gsub('$'+c.downcase, c)}
    s
  end




  def self.pack i, tag, dtag
    dl = dtag.length
    pos = i.enum_for(:scan, dtag).map {Regexp.last_match.begin(0)}
    return nil if pos.size%2 != 0
    next_pos = 0
    o = ''
    pos.each_slice(2).each do |b,e|
      o += i[next_pos..b-1]
      o += tag + (encode i[b+dl..e-1]) + tag
      next_pos = e + dl
    end
    o += i[next_pos..-1]
  end

  # return array (code, after tag there is a # ?, rest node)
  def self.unpack str, tag, default = '/.*/'
    # TODO what a empty unpacked is depends on the context
    end_tag_idx = (str.rindex tag) || 0
    return [nil, nil, str] if end_tag_idx == 0 or !str.start_with? tag
    code = decode str[tag.length..end_tag_idx-1]
    hash = code[0] == '#'
    code = code[1..-1] if hash
    node = str[end_tag_idx + tag.length..-1]
    return [code.empty? ? '/.*/' : code, hash, node.empty? ? nil : node]
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

  # functions throws or return the first node not parsed
  def match_node t, d, s = nil
    set_context t, d
    puts "#{s}> #{t.class} : #{t} vs #{d}"
    return d if t == nil
    assert (d != nil), "unexpected end of document"
    assert (t.class == d.class), "different class"

    # attributes
    ta = t.attribute_nodes
    da = d.attribute_nodes
    (zip_attributes ta, da).all? {|dt| match_nodea *dt}
    # retrieve context
    set_context t, d

    # the tagname
    match_string t.name, d.name, d

    # content if this is a text element
    match_string t.content, d.content if t.class == Nokogiri::XML::Text

    # children
    (t.children.zip d.children).map {|dt| match_nodec *dt}.last
  end

  def unpack str, default = nil
    return self.class.unpack str, tag, default
  end

  def unpack_attr string
    code, hash, node = unpack string, ''
    hash and !node ? code : nil
  end

  def zip_attributes ta, da
    # TODO add support for repeated attributes
    ta = ta.sort
    da = da.sort

    open = ta.any? {|a| (unpack_attr a.name) == 'open' && a.value == 'true'}
    optional = ta.map {|a| (unpack_attr a.name) == 'optional' ? (a.value.split ' ') : []}.flatten
    ignore = ta.map {|a| (unpack_attr a.name) == 'ignore' ? (a.value.split ' ') : []}.flatten
    ta.reject! {|a| ['open', 'optional', 'ignore'].include? (unpack_attr a.name)}
    #puts "open #{open}, optional #{optional}, ignore #{ignore}, ta #{ta}"

    ztd = []
    ta.each do |t|
      d = da.find {|a| a.name == t.name}
      if d
        da.delete_at (da.index d)
        ztd << [t, d]
      elsif !optional.include? t.name
        assert! "not found attribute #{t.name}"
      end
    end
    assert (open || da.all? {|a| ignore.include? a.name}), "found unknown attribute"
    ztd
  end

  # '&&# code && text' -> eval code with context_d, compare text against d (if text is not the empty string)
  # '&& code && text' -> eval code with d, compare text against d (if text is not the empty string)
  def match_string t, d, context_d = d
    code, hash, node = unpack t
    puts "XXX #{[code, hash, node, d, context_d]}"
    eval_code code, (hash ? context_d : d)
    string_comparer node, d if node != nil
  end

  def eval_code code, node
    return if code == nil
    if code[0] == '/' and code[-1] == '/'
      re = Regexp.new code[1..-2]
      assert (re.match node), "regexp failed"
    else
      res = eval code, (default_binding node)
      if res < NokoteGrammar
        #node = (resolve res, node)
        puts "jump from #{node} to ..."
        assert! "not implemented jumps"
      end
      true
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
    if !cond
      message = %q(error matching at template:#{@tcur.line} document:#{@dcur.line} #{msg}
  template_node: #{@tcur}
  document_node: #{@dcur}
  at
  #{caller.join("\n  ")})
      puts message
      raise NotokeParserError, message
      return false
    end
    true
  end
end


end
