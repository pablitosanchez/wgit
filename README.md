# Wgit

[![Inline gem version](https://badge.fury.io/rb/wgit.svg)](https://rubygems.org/gems/wgit)
[![Inline downloads](https://img.shields.io/gem/dt/wgit)](https://rubygems.org/gems/wgit)
[![Inline build](https://travis-ci.org/michaeltelford/wgit.svg?branch=master)](https://travis-ci.org/michaeltelford/wgit)
[![Inline docs](http://inch-ci.org/github/michaeltelford/wgit.svg?branch=master)](http://inch-ci.org/github/michaeltelford/wgit)
[![Inline code quality](https://api.codacy.com/project/badge/Grade/d5a0de62e78b460997cb8ce1127cea9e)](https://www.codacy.com/app/michaeltelford/wgit?utm_source=github.com&amp;utm_medium=referral&amp;utm_content=michaeltelford/wgit&amp;utm_campaign=Badge_Grade)

---

Wgit is a Ruby gem similar in nature to GNU's `wget` tool. It provides an easy to use API for programmatic web scraping, indexing and searching.

Fundamentally, Wgit is a WWW indexer/scraper which crawls URL's, retrieves and serialises their page contents for later use. You can use Wgit to copy entire websites if required. Wgit also provides a means to search indexed documents stored in a database. Therefore, this library provides the main components of a WWW search engine. The Wgit API is easily extended allowing you to pull out the parts of a webpage that are important to you, the code snippets or tables for example. As Wgit is a library, it supports many different use cases including data mining, analytics, web indexing and URL parsing to name a few.

Check out this [example application](https://search-engine-rb.herokuapp.com) - a search engine (see its [repository](https://github.com/michaeltelford/search_engine)) built using Wgit and Sinatra, deployed to Heroku. Heroku's free tier is used so the initial page load may be slow. Try searching for "Ruby" or something else that's Ruby related.

## Table Of Contents

1. [Installation](#Installation)
2. [Basic Usage](#Basic-Usage)
3. [Documentation](#Documentation)
4. [Practical Examples](#Practical-Examples)
5. [Practical Database Example](#Practical-Database-Example)
6. [Extending The API](#Extending-The-API)
7. [Caveats](#Caveats)
8. [Executable](#Executable)
9. [Change Log](#Change-Log)
10. [Development](#Development)
11. [Contributing](#Contributing)
12. [License](#License)

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'wgit'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install wgit

## Basic Usage

Below shows an example of API usage in action and gives an idea of how you can use Wgit in your own code.

```ruby
require 'wgit'

crawler = Wgit::Crawler.new
url = Wgit::Url.new 'https://wikileaks.org/What-is-Wikileaks.html'

doc = crawler.crawl url

doc.class # => Wgit::Document
doc.stats # => {
# :url=>44, :html=>28133, :title=>17, :keywords=>0,
# :links=>35, :text_snippets=>67, :text_bytes=>13735
#}

# doc responds to the following methods:
Wgit::Document.instance_methods(false).sort # => [
#   :==, :[], :author, :base, :base_url, :css, :date_crawled, :doc, :empty?,
#   :external_links, :external_urls, :find_in_html, :find_in_object, :html,
#   :init_nokogiri, :internal_absolute_links, :internal_full_links,
#   :internal_links, :keywords, :links, :relative_absolute_links,
#   :relative_absolute_urls, :relative_full_links, :relative_full_urls,
#   :relative_links, :relative_urls, :score, :search, :search!, :size, :stats,
#   :text, :title, :to_h, :to_json, :url, :xpath
# ]

results = doc.search 'corruption'
results.first # => "ial materials involving war, spying and corruption.
              #     It has so far published more"
```

## Documentation

100% of Wgit's code is documented using [YARD](https://yardoc.org/), deployed to [Rubydocs](https://www.rubydoc.info/gems/wgit). This greatly benefits developers in using Wgit in their own programs. Another good source of information (as to how the library behaves) are the tests. Also, see the [Practical Examples](#Practical-Examples) section below for real working examples of Wgit in action.

## Practical Examples

Below are some practical examples of Wgit in use. You can copy and run the code for yourself.

### WWW HTML Indexer

See the `Wgit::Indexer#index_the_web` documentation and source code for an already built example of a WWW HTML indexer. It will crawl any external url's (in the database) and index their markup for later use, be it searching or otherwise. It will literally crawl the WWW forever if you let it!

See the [Practical Database Example](#Practical-Database-Example) for information on how to setup a database for use with Wgit.

### Website Downloader

Wgit uses itself to download and save fixture webpages to disk (used in tests). See the script [here](https://github.com/michaeltelford/wgit/blob/master/test/mock/save_site.rb) and edit it for your own purposes.

### Broken Link Finder

The `broken_link_finder` gem uses Wgit under the hood to find and report a website's broken links. Check out its [repository](https://github.com/michaeltelford/broken_link_finder) for more details.

### CSS Indexer

The below script downloads the contents of the first css link found on Facebook's index page.

```ruby
require 'wgit'
require 'wgit/core_ext' # Provides the String#to_url and Enumerable#to_urls methods.

crawler = Wgit::Crawler.new
url = 'https://www.facebook.com'.to_url

doc = crawler.crawl url

# Provide your own xpath (or css selector) to search the HTML using Nokogiri underneath.
hrefs = doc.xpath "//link[@rel='stylesheet']/@href"

hrefs.class # => Nokogiri::XML::NodeSet
href = hrefs.first.value # => "https://static.xx.fbcdn.net/rsrc.php/v3/y1/l/0,cross/NvZ4mNTW3Fd.css"

css = crawler.crawl href.to_url
css[0..50] # => "._3_s0._3_s0{border:0;display:flex;height:44px;min-"
```

### Keyword Indexer (SEO Helper)

The below script downloads the contents of several webpages and pulls out their keywords for comparison. Such a script might be used by marketeers for search engine optimisation for example.

```ruby
require 'wgit'

my_pages_keywords = ['Everest', 'mountaineering school', 'adventure']
my_pages_missing_keywords = []

competitor_urls = [
  'http://altitudejunkies.com',
  'http://www.mountainmadness.com',
  'http://www.adventureconsultants.com'
]

crawler = Wgit::Crawler.new competitor_urls

crawler.crawl do |doc|
  # If there are keywords present in the web document.
  if doc.keywords.respond_to? :-
    puts "The keywords for #{doc.url} are: \n#{doc.keywords}\n\n"
    my_pages_missing_keywords.concat(doc.keywords - my_pages_keywords)
  end
end

if my_pages_missing_keywords.empty?
  puts 'Your pages are missing no keywords, nice one!'
else
  puts 'Your pages compared to your competitors are missing the following keywords:'
  puts my_pages_missing_keywords.uniq
end
```

## Practical Database Example

This next example requires a configured database instance. Currently the only supported DBMS is MongoDB. See [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) for a free (small) account or provide your own MongoDB instance.

`Wgit::Database` provides a light wrapper of logic around the `mongo` gem allowing for simple database interactivity and object serialisation. Using Wgit you can index webpages, store them in a database and then search through all that's been indexed. The use of a database is entirely optional however and isn't required for crawling/indexing.

The following versions of MongoDB are supported:

| Gem    | Database |
| ------ | -------- |
| ~> 2.9 | ~> 4.0   |

### Setting Up MongoDB

Follow the steps below to configure MongoDB for use with Wgit. This is only needed if you want to read/write database records.

1) Create collections for: `documents` and `urls`.
2) Add a [*unique index*](https://docs.mongodb.com/manual/core/index-unique/) for the `url` field in **both** collections.
3) Enable `textSearchEnabled` in MongoDB's configuration (if not already so).
4) Create a [*text search index*](https://docs.mongodb.com/manual/core/index-text/#index-feature-text) for the `documents` collection using:
```json
{
  "text": "text",
  "author": "text",
  "keywords": "text",
  "title": "text"
}
```
5) Set the connection details for your MongoDB instance (see below) using `Wgit.set_connection_details` (prior to calling `Wgit::Database#new`)

**Note**: The *text search index* (in step 4) lists all document fields to be searched by MongoDB when calling `Wgit::Database#search`. Therefore, you should append this list with any other fields that you want searched. For example, if you [extend the API](#Extending-The-API) then you might want to search your new fields in the database by adding them to the index above.

### Database Example

The below script shows how to use Wgit's database functionality to index and then search HTML documents stored in the database. If you're running the code for yourself, remember to replace the database [connection string](https://docs.mongodb.com/manual/reference/connection-string/) with your own.

```ruby
require 'wgit'
require 'wgit/core_ext' # => Provides the String#to_url and Enumerable#to_urls methods.

### CONNECT TO THE DATABASE ###

# Set your connection details manually (as below) or from the environment using
# Wgit.set_connection_details_from_env
Wgit.set_connection_details('DB_CONNECTION_STRING' => '<your_connection_string>')
db = Wgit::Database.new # Connects to the database...

### SEED SOME DATA ###

# Here we create our own document rather than crawling the web (which works in the same way).
# We pass the web page's URL and HTML Strings.
doc = Wgit::Document.new(
  'http://test-url.com'.to_url,
  "<html><p>How now brown cow.</p><a href='http://www.google.co.uk'>Click me!</a></html>"
)
db.insert doc

### SEARCH THE DATABASE ###

# Searching the database returns Wgit::Document's which have fields containing the query.
query = 'cow'
results = db.search query

search_result = results.first
search_result.class           # => Wgit::Document
doc.url == search_result.url  # => true

### PULL OUT THE BITS THAT MATCHED OUR QUERY ###

# Searching the returned documents gives the matching text from that document.
search_result.search(query).first # => "How now brown cow."

### SEED URLS TO BE CRAWLED LATER ###

db.insert search_result.external_links
urls_to_crawl = db.uncrawled_urls # => Results will include search_result.external_links.
```

## Extending The API

Indexing in Wgit is the means of downloading a web page and serialising parts of the content into accessible document attributes/methods. For example, `Wgit::Document#author` will return you the webpage's HTML tag value of `meta[@name='author']`.

By default, Wgit indexes what it thinks are the most important pieces of information from each webpage. This of course is often not enough given the nature of webpages and their differences from each other. Therefore, there exists a set of ways to extend the default indexing logic.

There are two ways to extend the indexing behaviour of Wgit:

1. Add the elements containing **text** that you're interested in to be indexed.
2. Define custom indexers matched to specific **elements** that you're interested in.

Below describes these two methods in more detail.

### 1. Extending The Default Text Elements

Wgit contains an array of `Wgit::Document.text_elements` which are the default set of webpage elements containing text; which in turn are indexed and accessible via `Wgit::Document#text`.

If you'd like the text of additional webpage elements to be returned from `Wgit::Document#text`, then you can do the following:

```ruby
require 'wgit'
require 'wgit/core_ext'

# Let's add the text of links e.g. <a> tags.
Wgit::Document.text_elements << :a

# Our Document has a link whose's text we're interested in.
doc = Wgit::Document.new(
  'http://some_url.com'.to_url,
  "<html><p>Hello world!</p>\
<a href='https://made-up-link.com'>Click this link.</a></html>"
)

# Now all crawled Documents will contain all visible link text in Wgit::Document#text.
doc.text # => ["Hello world!", "Click this link."]
```

**Note**: This only works for textual page content. For more control over the indexed elements themselves, see below.

### 2. Defining Custom Indexers Via Document Extensions

If you want full control over the elements being indexed for your own purposes, then you can define a custom indexer for each type of element that you're interested in.

Once you have the indexed page element, accessed via a `Wgit::Document` instance method, you can do with it as you wish e.g. obtain it's text value or manipulate the element etc. Since the returned types are plain [Nokogiri](https://www.rubydoc.info/github/sparklemotion/nokogiri) objects, you have the full control that the Nokogiri gem gives you.

Here's how to add a Document extension to index a specific page element:

```ruby
require 'wgit'
require 'wgit/core_ext'

# Let's get all the page's table elements.
Wgit::Document.define_extension(
  :tables,                  # Wgit::Document#tables will return the page's tables.
  '//table',                # The xpath to extract the tables.
  singleton: false,         # True returns the first table found, false returns all.
  text_content_only: false, # True returns one or more Strings of the tables text,
                            # false returns the tables as Nokogiri objects (see below).
) do |tables|
  # Here we can manipulate the object(s) before they're set as Wgit::Document#tables.
end

# Our Document has a table which we're interested in.
doc = Wgit::Document.new(
  'http://some_url.com'.to_url,
  '<html><p>Hello world!</p>\
<table><th>Header Text</th><th>Another Header</th></table></html>'
)

# Call our newly defined method to obtain the table data we're interested in.
tables = doc.tables

# Both the collection and each table within the collection are plain Nokogiri objects.
tables.class        # => Nokogiri::XML::NodeSet
tables.first.class  # => Nokogiri::XML::Element
```

**Note**: Wgit uses Document extensions to provide much of it's core functionality, providing access to a webpages text or links for example. These [default Document extensions](https://github.com/michaeltelford/wgit/blob/master/lib/wgit/document_extensions.rb) provide examples for your own.

**Extension Notes**:

- Any page links should be mapped into `Wgit::Url` objects; Url's are treated as Strings when being inserted into the database.
- Any object (like a Nokogiri object) will not be inserted into the database, it's up to you to map each object into a primitive type e.g. `Boolean, Array` etc.

## Caveats

Below are some points to keep in mind when using Wgit:

- All absolute `Wgit::Url`'s must be prefixed with an appropiate protocol e.g. `https://` etc.
- By default, up to 5 URL redirects will be followed; this is configurable however.
- IRI's (URL's containing non ASCII characters) are supported and will be normalised/escaped prior to being crawled.

## Executable

Currently there is no executable provided with Wgit, however...

In future versions of Wgit, an executable will be packaged with the gem. The executable will provide a `pry` console with the `wgit` gem already loaded. Using the console, you'll easily be able to index and search the web without having to write your own scripts.

This executable will be similar in nature to `./bin/console` which is currently used for development and isn't packaged as part of the `wgit` gem.

## Change Log

See the [CHANGELOG.md](https://github.com/michaeltelford/wgit/blob/master/CHANGELOG.md) for differences (including any breaking changes) between releases of Wgit.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Contributing

Bug reports and feature requests are welcome on [GitHub](https://github.com/michaeltelford/wgit/issues). Just raise an issue, checking it doesn't already exist.

The current road map is rudimentally listed in the [TODO.txt](https://github.com/michaeltelford/wgit/blob/master/TODO.txt) file. Maybe your feature request is already there?

## Development

For a full list of available Rake tasks, run `bundle exec rake help`. The most commonly used tasks are listed below...

After checking out the repo, run `bundle exec rake setup` to install the dependencies (requires `bundler`). Then, run `bundle exec rake test` to run the tests. You can also run `bundle exec rake console` for an interactive (`pry`) REPL that will allow you to experiment with the code.

To generate code documentation run `bundle exec yardoc`. To browse the generated documentation in a browser run `bundle exec yard server -r`. You can also use the `yri` command line tool e.g. `yri Wgit::Crawler#crawl_site` etc.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, see the *Gem Publishing Checklist* section of the `TODO.txt` file.
