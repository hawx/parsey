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
#     #=> {"file-name"=>"my file", "ext"=>"txt"}
#
class Parsey

  class ParseError < StandardError; end

  attr_accessor :to_parse, :pattern, :partials, :scanners
  
  # Depth keeps track of how many levels the optional blocks go down, so that the scanner
  # to use can be properly tracked. Each level of recursion needs a new scanner object 
  # to refer to or it will just clear the text that was stored.
  attr_accessor :depth
  
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

    @scanners = []
    @depth = -1
  end
  
  # This is a convenience method to allow you to easily parse something
  # in just one line
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
  
  # This is a front for r_place so that a regex is returned as expected
  #
  # @param [Array] pat the pattern to turn into a regular expression
  # @return [Regexp] the regex that will be used for parsing
  # @see r_place
  def regex
    Regexp.new(r_place(scan))
  end
  
  # @return [StringScanner] the current scanner to use
  def scanner
    @scanners[@depth]
  end
  
  # Finds matches from +to_parse+ using #regex. Then uses this data
  # and the pattern created with #scan to match the data with names.
  #
  # @return [Hash{String => String}] 
  #   the data taken fron +to_parse+
  def parse
    match = @to_parse.match(self.regex).captures
    data = {}
    
    self.scan.flatten.each_with_index do |block, i|
      type = block[0]
      name = block[1]
      if (type == :block) && (match[i] != nil)
        data[name] = match[i]
      end
    end
    
    data
  end
  
  
  # Need to reset scanners after every full run, so this provides a front 
  # for r_scan, which resets +scanners+ and still returns the correct value.
  #
  # @see #r_scan
  # @return [ScanArray]
  def scan
    r = self.r_scan(@pattern)
    @scanners =[]
    r
  end
  
  # Creates a new StringScanner, then scans for blocks, optionals or text 
  # and adds the result to +parsed+ until it reaches the end of +str+.
  #
  # @param [String] str the string to scan through
  # @return [ScanArray]
  def r_scan(str)
    parsed = ScanArray.new
    
    @depth += 1
    @scanners[@depth] = StringScanner.new(str)
    until self.scanner.eos?
      a = scan_blocks ||  a = scan_optionals ||  a = scan_text
      parsed << a
    end
    @depth -= 1
    
    parsed
  end
  
  # Finds next {...} in the StringScanner, and checks that it is closed.
  #
  # @return [Array] 
  #   an array of the form [:block, ...]
  def scan_blocks
    return unless self.scanner.scan(/\{/)
    content = scan_until(:block)
    
    raise ParseError unless self.scanner.scan(/\}/) # no closing block
    raise NoPartialError unless @partials[content]
    
    [:block, content]
  end
  
  # Finds next <...> in the StringScanner, and checks that it is closed.
  # Then scans the contents of the optional block.
  #
  # @return [Array] 
  #   an array of the form [:optional, [...]]
  def scan_optionals
    return unless self.scanner.scan(/</)
    content = scan_until(:optional)
    
    raise ParseError unless self.scanner.scan(/>/) # no closing block
    
    [:optional, r_scan(content)]
  end
  
  # Finds plain text, and checks whether there are any blocks left.
  #
  # @return [Array] 
  #   text before next block, or rest of text in the form [:text, ...]
  def scan_text
    text = scan_until(:open)
    
    if text.nil?
      text = self.scanner.rest
      self.scanner.clear
    end
    
    [:text, text]
  end

  # Scans the string until a tag is found of the type given.
  #
  # @param [Symbol] type of tag to look for
  #   :block for a closing block tag +}+
  #   :optional for a closing optional tag +>+
  #   :open for an opening tag +{+ or +<+
  # @return [String, nil] 
  #   the text before the tag, or nil if no match found
  def scan_until(type)
    case type
    when :block
      regex = /\}/
    when :optional
      regex = />/
    when :open
      regex = /(\{|<)/
    end
    pos = self.scanner.pos
    if self.scanner.scan_until(regex)
      self.scanner.pos -= self.scanner.matched.size
      self.scanner.pre_match[pos..-1]
    end
  end
  
  # Puts the regexps in the correct place, but returns a string so it can
  # still work recursively
  #
  # @param [Array] pat the pattern to turn into a regular expression
  # @return [String] the regular expression as a string
  def r_place(pat)
    str = ''
    pat.each do |b|
      type = b[0]
      content = b[1]
      case type
      when :block
        str << @partials[content]
      when :text
        str << content
      when :optional
        str << "(#{r_place(content)})?"
      end
    end
    
    str
  end
  
  # ScanArray is an array of tokens created when scanning the pattern. 
  # It looks like this:
  #   [[:block, 'what-'], [:optional, [[:text, "hi-"]]], [:text, "oh"]]
  #
  class ScanArray < Array
    
    # @see #flatten
    def flatten!
      self.replace(self.flatten)
    end
    
    # Removes all :text nodes from +pat+ and puts :optional nodes contents' into the
    # main array, and puts a nil in place
    #
    # @return [Array]
    #
    # @example
    #  
    #   sa = ScanArray.new([[:text, 'hey-'], 
    #                       [:optional, 
    #                         [[:block, '([a-z]+)'], 
    #                          [:text, '-what']]
    #                      ]])
    #
    #   sa.flatten
    #     #=> [[:optional, nil], [:block, "([a-z]+)"]]
    #
    def flatten
      # Flatten the array with Array#flatten before starting
      flat = super
      
      indexes = []
      flat.each_with_index do |v, i|
        if v == :optional
          indexes << i
        end
      end
      
      # Need to start from the back so as not to alter the indexes of the 
      # other items when inserting
      indexes.reverse.each do |i|
        flat.insert(i+1, nil)
      end
      
      flat.reverse!
      r = ScanArray.new
      while flat.size > 0
        r << [flat.pop, flat.pop]
      end
      
      r.delete_if {|i| i[0] == :text}
      r
    end
    
    # Loops through the types and contents of each tag separately, passing them
    # to the block given.
    #
    # @yield [Symbol, Object] gives the type and content of each block in turn
    #
    # @example
    #  
    #   sa = ScanArray.new([[:text, 'hey-'], 
    #                       [:optional, 
    #                         [[:block, '([a-z]+)'], 
    #                          [:text, '-what']]
    #                      ]])
    #
    #   sa.each_with_type do |type, content|
    #     puts "#{type} -> #{content}"
    #   end
    #   #=> text -> hey-
    #   #=> optional -> [[:block, "([a-z]+)"], [:text, "-what"]]
    #  
    def each_with_type(&blck)
      ts = self.collect {|i| i[0]}
      cs = self.collect {|i| i[1]}
      (0...ts.size).each do |i|
        yield(ts[i], cs[i])
      end
    end
    
  end
end
