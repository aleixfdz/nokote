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

data = OpenStruct.new
if Nokote::parse_document template, html_doc, data
  puts "parsed document, retrieved data: #{data}"
else
  puts "invalid document!"
end
```

prints  `parsed document, retrieved data: #<OpenStruct text="some text", id="value">`
