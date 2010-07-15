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
  
  should "create correct order" do
    partials = {'folder' => 'f', 'name' => 'n', 'ext' => 'e'}
    t = Parsey.new('', '<{folder}/>{name}.{ext}', partials)
    assert_equal [nil, 'folder', 'name', 'ext'], t.order
  end
  
  should "create correct order when optional is in the middle" do
    partials = {'folder' => 'folder', 'name' => 'name', 'ext' => 'ext'}
    t = Parsey.new('', '{folder}/<{name}>.{ext}', partials)
    assert_equal ['folder', nil, 'name', 'ext'], t.order
  end
  
  should "parse properly" do
    partials = {'test' => '([a-z]+)', 'something' => '([a-z]+)'}
    t = Parsey.new('something:what', '{test}:{something}', partials)
    hash = {'test' => 'something', 'something' => 'what'}
    assert_equal hash, t.parse
  end
  
end
