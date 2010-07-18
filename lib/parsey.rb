require 'strscan'

# Parsey is a very simple class to match a string with a pattern and retrieve data from it.
# It takes a string, a pattern, and a hash of regexes. The pattern is filled with the regexes
# and then that is matched to the string given.
#
# The pattern uses {} to surround the name of the regex it should be replaced with. You can
# also use <> to surround parts of the pattern that are optional, though these obviously
# must be nested properly.
#
# @example
#
#   partials = {'folder'    => '([a-zA-Z0-9-]+)', 
#               'file-name' => '([a-zA-Z0-9_ -]+)', 
#               'ext'       => '(txt|jpg|png)'}
#
#   Parsey.parse('my-folder/my file.txt', '{folder}/{file-name}.{ext}', partials)
#     #=> {"folder"=>"my-folder", "file-name"=>"my file", "ext"=>"txt"}
#
#   Parsey.parse('my file.txt', '<{folder}/>{file-name}.{ext}', partials)
#     #=> {"folder"=>nil, "file-name"=>"my file", "ext"=>"txt"}
#
class Parsey

  class ParseError < StandardError; end

  attr_accessor :to_parse, :pattern, :partials, :data, :scanner
  
  # Creates a new Parsey instance.
  #
  # @param [String] to_parse 
  #   the string which is to be parsed
  # @param [String] pattern 
  #   for the string to match
  # @param [Hash{String => String}] partials
  #   the regex patterns (as strings) to use when matching
  #
  def initialize(to_parse, pattern, partials)
    @to_parse = to_parse
    @pattern  = pattern
    @partials = partials

    @data = {}
  end
  
  # Runs through +pattern+ and replaces each of the keywords with the
  # correct regex from +partials+. It then adds '()?' round any parts of
  # the pattern marked optional. And turns the final string into a regex.
  #
  # @return [Regex] 
  #   the regular expression to match against when parsing
  #
  def regex
    m = @pattern.gsub(/\{([a-z-]+)\}/) do
      @partials[$1]
    end
    
    # replace optional '<stuff>'
    m.gsub!(/<(.+)>/) do
      "(#{$1})?"
    end
    
    Regexp.new(m)
  end
  
  def regex
    m = @pattern.gsub(/\{([a-z-]+)}/) do
      @partials[$1]
    end
    
    # replace optional +<stuff>+
    m.gsub!(/<(.+)>/) do
      $1
    end
    
    Regexp.new(m)
  end
  
  # Gets the order of the different tags within the pattern. It inserts nil
  # when it encounters an optional section so that it can easily be skipped
  # during parsing.
  #
  # @return [Array]
  #   the order in which the tags appear in the +pattern+
  #
  def order
    if @pattern =~ /<(.+)>/
      parts = @pattern.dup.split('<')
      parts.insert(1, nil)
      parts.collect! {|i| 
        i.split('>') unless i.nil?
      }.flatten!
      
      parts.collect! {|i| 
        i.split('}') unless i.nil?
      }.flatten!
      
      parts.collect! {|i|
        i.gsub!(/[^a-zA-Z0-9_-]/, '') unless i.nil?
      }
      
      parts.delete_if {|i| i == ''}
      
      return parts
    else
      parts = []
      @pattern.gsub(/\{([a-z-]+)\}/) do
        parts << $1
      end
      return parts
    end
  end
  
  # This does the parsing of +to_parse+ using +regex+. It fills the hash
  # +data+ using +order+ to match the data up with the correct name.
  #
  # @return [Hash{String => String}] 
  #   the data retrieved from +to_parse+
  #
  def parse
    match = @to_parse.match(regex).captures
    pat = scan(@pattern)
    reg = place(pat)
    get(@to_parse, reg, pat)
  end
  
  # Uses the parsed array to get the data and put it into a hash
  #
  # @param [String] str the string to parse
  # @param [Regexp] reg the regex to use to get data from +str+
  # @param [Array] pat the pattern created from #scan
  def get(str, reg, pat)
    match = str.match(reg).captures
    pat2 = pat.delete_if {|i| i[0] == :text}
    
    i = 0
    pat2.each do |part|
      if part[0] == :tag
        p match[i]
      elsif part[0] == :optional
        p get(
      end
      
      i += 1
    end
  end
  
  # This is a front for r_place so that a regex is returned as expected
  def place(pat)
    Regexp.new(r_place(pat))
  end
  
  # Puts the regexs in the correct place, but returns a string so it can
  # still work recursively
  def r_place(pat)
    str = ''
    pat.each do |b|
      type = b[0]
      content = b[1]
      case type
      when :tag
        str << content
      when :text
        str << content
      when :optional
        str << "(#{r_place(content)})?"
      end
    end
    
    str
  end
  
  # @return [Array] of the form [[:type, content], [:optional, [[:type, content], ...]], ...]
  def scan(str)
    @scanner = StringScanner.new(str)
    parsed = []
    
    until @scanner.eos?
      a = scan_tags ||  a = scan_optionals ||  a = scan_text
      parsed << a
    end
    
    parsed
  end
  
  # Find {tags}
  def scan_tags
    return unless @scanner.scan(/\{/)
    content = scan_until_closed(:tag)
    
    raise ParseError unless @scanner.scan(/\}/) # no closing tag
    raise NoPartialError unless @partials[content]
    
    [:tag, @partials[content]]
  end
  
  # Find <tags>
  def scan_optionals
    return unless @scanner.scan(/</)
    content = scan_until_closed(:optional)
    
    raise ParseError unless @scanner.scan(/>/) # no closing tag
    
    [:optional, scan(content)]
  end
  
  # Check whether rest of text includes any tags
  def scan_text
    text = scan_until_tag
    
    if text.nil?
      text = @scanner.rest
      @scanner.clear
    end
    
    [:text, text]
  end
  
  # Scans the string until a tag is found then returns the string
  # before the tag. If no match nil is returned.
  def scan_until_tag
    pos = @scanner.pos
    if @scanner.scan_until(/(\{|<)/)
      @scanner.pos -= @scanner.matched.size
      @scanner.pre_match[pos..-1]
    end
  end
  
  def scan_until_closed(type)  
    regex = nil
    if type == :tag
      regex = /\}/
    elsif type == :optional
      regex = />/
    end
    pos = @scanner.pos
    if @scanner.scan_until(regex)
      @scanner.pos -= @scanner.matched.size
      @scanner.pre_match[pos..-1]
    end
  end
  
  # This is a convenience method to allow you to easily parse something
  # in just one go!
  #
  # @param [String] to_parse 
  #   the string which is to be parsed
  # @param [String] pattern 
  #   for the string to match
  # @param [Hash{String => String}] partials
  #   the regex patterns (as strings) to use when matching
  #
  # @return [Hash{String => String}]
  #   the data retrieved from +to_parse+
  #
  def self.parse(to_parse, pattern, partials)
    a = Parsey.new(to_parse, pattern, partials)
    a.parse
  end
  
end

Parsey.new("my-string", "{word}-<{word}>", {'word' => '([a-z]+)'}).parse
