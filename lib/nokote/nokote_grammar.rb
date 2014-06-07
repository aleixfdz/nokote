module Nokote


class NokoteGrammar
 private
  # TODO refactor
  def get_rules r
    r.class < NokoteGrammar ? r.subrules : r
  end
end

class Optional < NokoteGrammar
  def initialize rules; @rules = rules; end
  def subrules; rules.map {|r| get_rules r}.flatten; end
  def rules; @rules; end
  def to_s; "(" + rules.join(" | ") + ")"; end
end
class Concat < NokoteGrammar
  def initialize *rules; @rules = rules; end
  def subrules; rules.map {|r| get_rules r}.flatten; end
  def rules; @rules; end
  def to_s; rules.join(" "); end
end
class Repeat < NokoteGrammar
  def initialize rule, min, max; @rule = rule; @min = min; @max = max; end
  def subrules; get_rules rule; end
  def rule; @rule; end
  def min; @min; end
  def max; @min; end
  def to_s; "#{rule}{#{min}, #{max}}"; end
end
class OnCandidates < NokoteGrammar
  def initialize rule, &block; @rule = rule; @block = block; end
  def subrules; get_rules rule; end
  def rule; @rule; end
  def generator; @block; end
  def to_s; "#{rule}@{block.to_s}"; end
end
class Empty < NokoteGrammar
  def initialize; end
  def subrules; []; end
  def to_s; "$empty_node"; end
end
class FinalNode < NokoteGrammar
  def initialize; end
  def subrules; []; end
  def to_s; "$final_node"; end
end


end


def o *rs; Nokote::Optional.new *rs; end
def c *rs; Nokote::Concat.new *rs; end
def r r, n, x; Nokote::Repeat.new r, n, x; end
def g r, &b; Nokote::OnCandidates r, &b; end
def empty; Nokote::Empty.new ; end
def final_node; Nokote::FinalNode.new ; end
def inf; Float::IFINITY; end
