# frozen_string_literal: true

require 'webmock'
require 'uri'

include WebMock::API

WebMock.enable!
WebMock.disable_net_connect!

def fixtures_dir
  'test/mock/fixtures'
end

# Return the contents of a fixture HTML file.
def fixture(path)
  path = "#{path}.html" unless path.end_with?('.html')
  file_path = path.start_with?(fixtures_dir) ? path : "#{fixtures_dir}/#{path}"
  File.read(file_path)
end

# Return the default HTML fixture data.
def default_html
  fixture('test_doc')
end

# Stub a single webpage. Stubs both:
# http://blah.com/hi and http://blah.com/hi/ (with trailing slash).
def stub_page(url, status: 200, body: default_html, fixture: nil)
  body = fixture(fixture) if fixture
  stub_request(:get, url).to_return(status: status, body: body)

  # Webmock only mocks a trailing slash if there's no path so we do it.
  path = URI(url).path
  unless path.empty? or path == '/'
    alt_url = url.end_with?('/') ? url.chop : "#{url}/"
    stub_request(:get, alt_url).to_return(status: status, body: body)
  end
end

# Stub a single page 404 not found.
def stub_not_found(url)
  stub_page(url, status: 404, fixture: 'not_found')
end

# Stub a single page 301 redirect.
def stub_redirect(from, to)
  stub_request(:get, from).to_return(status: 301, headers: { 'Location': to })
end

# Stub a single page network timeout/unknown host error.
def stub_timeout(url)
  stub_request(:get, url).to_timeout
end

# Stub an entire website recursively according to what's saved on the file
# system. Assumes the fixture data exists on disk.
def stub_dir(url, path, dir)
  url.chop!  if url.end_with?('/')  # Remove trailing slash.
  path.chop! if path.end_with?('/') #   "
  dir.chop!  if dir.end_with?('/')  #   "

  url  += "/#{dir}" unless URI(url).host == dir
  path += "/#{dir}"

  objects = Dir["#{path}/{*,.*}"]
            .reject { |f| f.end_with?('.') || f.end_with?('..') }
  files = objects
          .select { |obj| File.file?(obj) }
          .reject { |f| f.end_with?('index.html') }
          .map { |f| f.end_with?('.html') ? f[0..-6] : f }
  dirs = objects.select { |obj| File.directory?(obj) }

  files.each { |f| stub_page("#{url}/#{f.split('/').last}", fixture: f) }
  dirs.each  { |d| stub_dir(url, path, d.split('/').last) }
end

# Stub all single webpages and full websites from the fixtures directory.
def stub_fixtures(pages, sites)
  pages.each do |url|
    path = URI(url).host
    stub_page(url, fixture: path)
  end

  sites.each do |url|
    dir = URI(url).host
    stub_page(url, fixture: "#{dir}/index")
    stub_dir(url, fixtures_dir, dir)
  end
end
