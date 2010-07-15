# parsey

Parsey is a very simple class to match a string with a pattern and retrieve data from it.
It takes a string, a pattern, and a hash of regexes. The pattern is filled with the regexes
and then that is matched to the string given.

The pattern uses {} to surround the name of the regex it should be replaced with. You can
also use <> to surround parts of the pattern that are optional, though these obviously
must be nested properly.

## Example

    partials = {'folder'    => '([a-zA-Z0-9-]+)', 
               'file-name' => '([a-zA-Z0-9_ -]+)', 
               'ext'       => '(txt|jpg|png)'}
    
    Parsey.parse('my-folder/my file.txt', '{folder}/{file-name}.{ext}', partials)
     #=> {"folder"=>"my-folder", "file-name"=>"my file", "ext"=>"txt"}
    
    Parsey.parse('my file.txt', '<{folder}/>{file-name}.{ext}', partials)
     #=> {"folder"=>nil, "file-name"=>"my file", "ext"=>"txt"}

## Copyright

Copyright (c) 2010 Joshua Hawxwell. See LICENSE for details.
