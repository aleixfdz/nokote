module Nokote


class NokoteGrammar
end

class Optional < NokoteGrammar
  def initialize rules; @rules = rules; end
  def rules; @rules; end
  def to_s; "(" + rules.join(" | ") + ")"; end
end
class Concat < NokoteGrammar
  def initialize *rules; @rules = rules; end
  def rules; @rules; end
  def to_s; rules.join(" "); end
end
class Repeat < NokoteGrammar
  def initialize rule, min, max; @rule = rule; @min = min; @max = max; end
  def rule; @rule; end
  def min; @min; end
  def max; @min; end
  def to_s; "#{rule}{#{min}, #{max}}"; end
end
class OnCandidates < NokoteGrammar
  def initialize rule, &block; @rule = rule; @block = block; end
  def rule; @rule; end
  def generator; @block; end
  def to_s; "#{rule}@{block.to_s}"; end
end
class Empty < NokoteGrammar
  def initialize; end
  def to_s; "$empty_node"; end
end
class FinalNode < NokoteGrammar
  def initialize; end
  def to_s; "$final_node"; end
end


def o rs; Optional.new rs; end
def c rs; Concat.new rs; end
def r r, n, x; Repeat.new r, n, x; end
def g r, &b; OnCandidates r, &b; end
def empty; Empty.new ; end
def final_node; FinalNode.new ; end


end
