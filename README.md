# Nokote

Parse HTML documents
```{.html}
<tag id="value">some text</tag>
```

writing HTML templates embedding ruby code
```{.html}
<tag id="&&tp.data.id = tp.node&&">&&tp.data.text = tp.node&&</tag>
```

```{.ruby}
require 'nokote'
require 'ostruct'

html_doc = '<tag id="value">some text</tag>'
template = '<tag id="&&true&&">&&tp.data.text = tp.node&&</tag>'

parser = Nokote::NokoteParser.new template
data = OpenStruct.new
if parser.parse html_doc, data
  puts "parsed document, retrieved data: #{data}"
else
  puts "invalid document!"
end
```

prints  `parsed document, retrieved data: #<OpenStruct text="some text", id="value">`


## Installation

Add this line to your application's Gemfile:

    gem 'nokote'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install nokote


## Contributing

1. Fork it ( https://github.com/[my-github-username]/nokote/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
