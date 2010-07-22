require 'helper'

class TestParsey < Test::Unit::TestCase

  should "construct correct regular expression" do
    partials = {'test' => 'hello', 'something' => 'world'}
    t = Parsey.new('', '{test}|{something}', partials) 
    assert_equal %r{hello|world}, t.regex 
  end
  
  should "allow optional part of pattern" do
    partials = {'folder' => 'f', 'name' => 'n', 'ext' => 'e'}
    t = Parsey.new('', '<{folder}>/{name}.{ext}', partials)
    assert_equal Regexp.new("(f)?\/n.e"), t.regex
  end
  
  should "scan correctly" do
    partials = {'folder' => 'f', 'name' => 'n', 'ext' => 'e'}
    t = Parsey.new('', '<{folder}/>{name}.{ext}', partials)
    r = [[ :optional, [[:block, "folder"], [:text, "/"]] ], [:block, "name"], [:text, "."], [:block, "ext"]]
    assert_equal r, t.scan
  end
  
  should "create correct order when optional is in the middle" do
    partials = {'folder' => 'folder', 'name' => 'name', 'ext' => 'ext'}
    t = Parsey.new('', '{folder}/<{name}>.{ext}', partials)
    r = [[:block, "folder"], [:text, "/"], [:optional, [[:block, "name"]]], [:text, "."], [:block, "ext"]]
    assert_equal r, t.scan
  end
  
  should "parse properly" do
    partials = {'test' => '([a-z]+)', 'something' => '([a-z]+)'}
    t = Parsey.new('something:what', '{test}:{something}', partials)
    hash = {'test' => 'something', 'something' => 'what'}
    assert_equal hash, t.parse
  end
  
  should "parse long patterns properly" do
    partials = {'word' => '([a-z]+)',
                'number' => '([0-9]+)',
                'date' => '(\d{4}-\d{2}-\d{2})',
                'time' => '(\d{2}:\d{2})',
                'person' => '(John|Dave|Luke|Josh)'}
    
    pattern = 'Hello my name is {person}, I was born on {date} at {time}. I am {number} years old, and my favourite animal is a {word}.'
    string = 'Hello my name is Josh, I was born on 1992-09-17 at 06:24. I am 17 years old, and my favourite animal is a shark.'

    hash = {'person' => 'Josh', 'date' => '1992-09-17', 'time' => '06:24', 'number' => '17', 'word' => 'shark'}
    assert_equal hash, Parsey.parse(string, pattern, partials)
  end
  
  should "parse multiple optionals correctly" do
    partials = {'word' => '([a-z]+)',
                'number' => '([0-9]+)',
                'date' => '(\d{4}-\d{2}-\d{2})',
                'time' => '(\d{2}:\d{2})',
                'person' => '(John|Dave|Luke|Josh)'}
    pattern = 'Hello my name is {person}, I was born on {date}< at {time}>. I am {number} years old<, and my favourite animal is a {word}>.'
    string1 = 'Hello my name is Josh, I was born on 1992-09-17 at 06:24. I am 17 years old, and my favourite animal is a shark.'
    hash1 = {'person' => 'Josh', 'date' => '1992-09-17', 'time' => '06:24', 'number' => '17', 'word' => 'shark'}
    
    string2 = 'Hello my name is Josh, I was born on 1992-09-17 at 06:24. I am 17 years old.'
    hash2 = {'person' => 'Josh', 'date' => '1992-09-17', 'time' => '06:24', 'number' => '17'}
    
    string3 = 'Hello my name is Josh, I was born on 1992-09-17. I am 17 years old, and my favourite animal is a shark.'
    hash3 = {'person' => 'Josh', 'date' => '1992-09-17', 'number' => '17', 'word' => 'shark'}
    
    string4 = 'Hello my name is Josh, I was born on 1992-09-17. I am 17 years old.'
    hash4 = {'person' => 'Josh', 'date' => '1992-09-17', 'number' => '17'}
    
    assert_equal hash1, Parsey.parse(string1, pattern, partials)
    assert_equal hash2, Parsey.parse(string2, pattern, partials)
    assert_equal hash3, Parsey.parse(string3, pattern, partials)
    assert_equal hash4, Parsey.parse(string4, pattern, partials)
  end
  
  should "raise an error when blocks not closed" do  
    assert_raise Parsey::ParseError do
      Parsey.parse('what', '{question', {'question' => '([a-z ]+\?)'})
    end
  end
  
  should "raise an error when optional not closed" do
    assert_raise Parsey::ParseError do
      Parsey.parse('hmm', '<{sound}', {'sound' => '(hmm|boo)'})
    end
  end
  
end
