require 'base32'
require 'htmlentities'
require 'nokogiri'
require 'securerandom'
require 'set'
require_relative 'nokote_grammar.rb'


# TODO add debug mode please

module Nokote


class NokoteParser
 public
  # TODO change all this shit
  def self.init_encode
    Base32.table = 'abcdefghijklmnopqrstuvwxyzABCDEF'
  end

  def self.load_grammar file, secure_tag, template_tag = '&&'
    path =  File.dirname file
    rules = eval (IO.read file)
    templates_name = Set.new rules.keys.reject {|r| r[0] != '#'}
    puts "#{templates_name.to_a}"
    templates_name.merge (Set.new rules.values.map {|r| r.subrules}.flatten)
    puts "#{templates_name.to_a}"
    templates_name.map! {|thn| thn[1..-1]}
    templates = {}
    templates_name.each {|tn| templates[tn] = IO.read (path + '/' + tn)}
    raise ArgumentError, "invalid template names #{templates_name}" if !templates.all?
    self.new rules, templates, secure_tag, template_tag
  end

  def self.load_grammar_and_parse_document file, first_rule, doc, data = nil, error_message = nil, template_tag = '&&'
    init_encode
    tag = generate_tag doc
    parser = load_grammar file, tag, template_tag
    nil == (parser.parse_doc first_rule, doc, data, error_message)
  end

  def self.parse_document template, doc, data = nil, error_message = nil, template_tag = '&&'
    init_encode
    tag = generate_tag doc
    parser = self.new({'0' => Concat.new('#t', FinalNode.new)}, {'t' => template}, tag, template_tag)
    nil == (parser.parse_doc '0', doc, data, error_message)
  end

  def initialize rules, templates, secure_tag, template_tag = '&&'
    @@html_entities = HTMLEntities.new
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
    parse rt, node.children.first, data, error_message
  end

  def parse rt, node, data = nil, error_message = nil
    @data = data
    resolve rt, node
  end


 private
  def resolve rt, node
    res = resolve_impl rt, node
    backtrack! while res == false and backtrack?
    res
  end

  # returns false if it was not possible to parse
  # otherwise return the first node not parsed (nil)
  # it attempts to parse node and its siblings...
  def resolve_impl rt, node
    puts "resolve impl #{rt} at #{node.class} : #{node}"
    if rt.class < NokoteGrammar
      res = resolve_rule rt, node
    elsif rt[0] != '#'
      rule = @rules[rt]
      raise ArgumentError, "not found rule #{rt}" if rule == nil
      res = resolve_rule rule, node
    else
      template = @templates[rt[1..-1]]
      raise ArgumentError, "not found template #{rt[1..-1]}" if template == nil
      res = match_template template, node
    end
    puts "resolved #{rt} at #{node.class} #{node} : #{res == nil ? "nil" : res}"
    res
  end

  def add_backtrack cc, debug_message = nil
    puts "< add bt #{debug_message}"
    @backtrack.push cc 
  end

  def backtrack?
    !@backtrack.empty?
  end

  def backtrack!
    puts "< backtrack!"
    backtrack.pop.call
  end

  # returns false if it was not possible to parse
  # otherwise return the first node not parsed (nil)
  # it attempts to parse node and its siblings...
  def resolve_rule rule, node
    puts " apply #{rule} at #{node}"
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
      (0..rule.max-1).each do
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
=begin
TODO add cardinality depending on number of candidates?
TODO make that the node return is the next...
    when OnCandidates
      nodes = rule.generator.call node
      return false if nodes.empty?
      context = nil
      callcc {|cc| context = cc}
      return false if nodes.empty?
      add_backtrack context, "#{rule} : #{nodes}"
      resolve_impl rule.rule, nodes.shift
=end
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

  # returns false if it was not possible to parse
  # otherwise return the first node not parsed (nil)
  # it attempts to parse node and its siblings... TODO
  def match_template template, node
    puts " match #{template} at #{node}"
    begin
      t = template.children.first
      # try adjusting node if it can be required
      # note that if t.content.empty? we don't want to skip it...
      # TODO template limitation per node...
      t = t.next_sibling if node.class != Nokogiri::XML::Text and t.content.empty?
      while t != nil and node != nil
        set_context t, node
        match_node t, node
        t = t.next_sibling
        node = node.next_sibling
      end
      assert (t == nil or node != nil), "unexpected end of document #{t.class}, #{node.class}"
      node
    rescue NotokeParserError => ex
      puts "match fails #{ex}"
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




  # TODO ugly, refactor, it should accept open and end tags...
  def self.pack i, tag, dtag
    dl = dtag.length
    pos = i.enum_for(:scan, dtag).map {Regexp.last_match.begin(0)}
    return nil if pos.size%2 != 0
    next_pos = 0
    o = ''
    pos.each_slice(2).each do |b,e|
      o += i[next_pos..b-1] if b > 0
      o += tag + (encode i[b+dl..e-1]) + tag
      next_pos = e + dl
    end
    o += i[next_pos..-1]
  end

  # return array [code, after tag there is a # ?, rest node]
  def self.unpack str, tag, default = '/.*/'
    # TODO what a empty unpacked is depends on the context
    end_tag_idx = (str.rindex tag) || 0
    return [nil, nil, str] if end_tag_idx == 0 or !str.start_with? tag
    puts str
    puts tag.length
    puts str[tag.length..-1]
    puts end_tag_idx-1
    puts str[tag.length..end_tag_idx-1]
    code = decode str[tag.length..end_tag_idx-1]
    puts code
    hash = code[0] == '#'
    code = code[1..-1] if hash
    node = normalize_string str[end_tag_idx + tag.length..-1]
    puts node
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

  # functions throws if d node cannot be parsed with t
  def match_node t, d, s = 'sibling'
    set_context t, d
    puts "  #{s}> #{t.class} : #{t} vs #{d}"
    assert (t.class == d.class), "different class: #{t.class} #{d.class}"
    assert (t != nil || d != nil), "found nil nodes: #{t.class} #{d.class}"

    # the tagname
    parse_attributes = (match_string t.name, d.name, d) != true

    parse_children = true
    grammar_on_children = nil
    # attributes
    ta = t.attribute_nodes.sort
    ta.each do |a|
      un = unpack_attr a.name
      parse_children = a.value != 'false' if un == "parse_children"
      grammar_on_children = eval a.value if un == "grammar"
    end
    ta.reject! {|a| ['parse_children'].include? (unpack_attr a.name)}
    da = d.attribute_nodes.sort
    (zip_attributes ta, da).all? {|dt| match_nodea *dt} if parse_attributes
    # retrieve context
    set_context t, d

    # content if this is a text element
    match_string t.content, d.content if t.class == Nokogiri::XML::Text

    # children
    if grammar_on_children
      # cut backtrack
      tb = @backtrack
      @backtrack = []
      res = resolve grammar_on_children, d.children.first
      # restore backtrack
      # (lthough it's possible restore with the new backtrack points
      # ie @backtrack = tb + @backtrack, it has no sense sine in order to
      # simplify we don't allow a resolve to go up to the parents...
      @backtrack = tb
      assert res, "failed grammar"
    elsif parse_children
      assert (t.children.size == d.children.size), "different number of children"
      (t.children.zip d.children).map {|dt| match_nodec *dt}
    end
  end

  def unpack str, default = nil
    return self.class.unpack str, tag, default
  end

  def unpack_attr string
    code, hash, node = unpack string, ''
    if code != nil and (!hash or node != nil or code == '')
      raise ArgumentError, "invalid attribute code #{[code, hash, node]}"
    end
    code
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
    code, hash, t_text = unpack t
    puts "    match_string #{[code, hash, t_text, d, context_d]}"
    eval_code code, (hash ? context_d : d)
    string_comparer t_text, d if t_text != nil
    hash
  end

  def eval_code code, node
    return if code == nil
    if code[0] == '/' and code[-1] == '/'
      re = Regexp.new code[1..-2]
      assert (re.match node), "regexp failed"
    else
      res = eval code, (default_binding node)
      if res.class < NokoteGrammar
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

  def self.normalize_string s
    s = @@html_entities.decode s
    s.gsub! /\s+/, ' '
    s.strip
  end



 public
  def data
    @data
  end

  def node
    @node
  end

  def raw_content
    node.class < Nokogiri::XML::Text ? node.content : node
  end

  def content
    normalize_string raw_content
  end

  def normalize_string s
    self.class.normalize_string s
  end

  def string_comparer s0, s1
    ns0 = normalize_string s0
    ns1 = normalize_string s1
    set_context ns0, ns1
    assert (ns0 == ns1), "string comparer failed"
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
      bt = caller
      btln = bt.rindex {|x| x =~ /nokote_parser\.rb:[0-9]+:in/}
      bt = bt[0..btln] if btln > 0
      message = %Q(error matching at template:#{@tcur.line} document:#{@dcur.line} #{msg}
  template_node: #{@tcur}
  document_node: #{@dcur}
  at
  #{bt.join("\n  ")})
      puts message
      raise NotokeParserError, message
      return false
    end
    true
  end
end


end
