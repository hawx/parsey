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

  attr_accessor :to_parse, :pattern, :partials, :data
  
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
    @to_parse.match( self.regex ).captures.each_with_index do |item, i|
      unless self.order[i].nil?
        @data[ self.order[i] ] = item
      end
    end
    @data
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
