# frozen_string_literal: true

require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'net/http' # Requires 'uri'.

module Wgit
  # The Crawler class provides a means of crawling web based Wgit::Url's, turning
  # their HTML into Wgit::Document instances.
  class Crawler
    include Assertable

    # The default maximum amount of allowed URL redirects.
    @default_redirect_limit = 5

    class << self
      # Class level instance accessor methods for @default_redirect_limit.
      # Call using Wgit::Crawler.default_redirect_limit etc.
      attr_accessor :default_redirect_limit
    end

    # The urls to crawl.
    attr_reader :urls

    # The docs of the crawled @urls.
    attr_reader :docs

    # The Net::HTTPResponse of the most recently crawled URL or nil.
    attr_reader :last_response

    # Initializes the Crawler and sets the @urls and @docs.
    #
    # @param urls [*Wgit::Url] The URL's to crawl in the future using either
    #   Crawler#crawl_url or Crawler#crawl_site. Note that the urls passed here
    #   will NOT update if they happen to redirect when crawled. If in doubt,
    #   pass the url(s) directly to the crawl_* method instead of to the new
    #   method.
    def initialize(*urls)
      self.[](*urls)
      @docs = []
    end

    # Sets this Crawler's @urls.
    #
    # @param urls [*Wgit::Url] The URL's to crawl in the future using either
    #   crawl_url or crawl_site. Note that the urls passed here will NOT update
    #   if they happen to redirect when crawled. If in doubt, pass the url(s)
    #   directly to the crawl_* method instead of to the new method.
    def urls=(urls)
      @urls = []
      Wgit::Utils.each(urls) { |url| add_url(url) }
    end

    # Sets this Crawler's @urls.
    #
    # @param urls [*Wgit::Url] The URL's to crawl in the future using either
    #   crawl_url or crawl_site. Note that the urls passed here will NOT update
    #   if they happen to redirect when crawled. If in doubt, pass the url(s)
    #   directly to the crawl_* method instead of to the new method.
    def [](*urls)
      # If urls is nil then add_url (when called later) will set @urls = []
      # so we do nothing here.
      unless urls.nil?
        # Due to *urls you can end up with [[url1,url2,url3]] etc. where the
        # outer array is bogus so we use the inner one only.
        if  urls.is_a?(Enumerable) &&
            urls.length == 1 &&
            urls.first.is_a?(Enumerable)
          urls = urls.first
        end

        # Here we call urls= method using self because the param name is also
        # urls which conflicts.
        self.urls = urls
      end
    end

    # Adds the url to this Crawler's @urls.
    #
    # @param url [Wgit::Url] A URL to crawl later by calling a crawl_* method.
    #   Note that the url added here will NOT update if it happens to
    #   redirect when crawled. If in doubt, pass the url directly to the
    #   crawl_* method instead of to the new method.
    def <<(url)
      add_url(url)
    end

    # Crawls one or more individual urls using Wgit::Crawler#crawl_url
    # underneath. See Wgit::Crawler#crawl_site for crawling entire sites. Note
    # that any external redirects are followed. Use Wgit::Crawler#crawl_url if
    # this isn't desirable.
    #
    # @param urls [Array<Wgit::Url>] The URLs to crawl.
    # @yield [Wgit::Document] If provided, the block is given each crawled
    #   Document. Otherwise each doc is added to @docs which can be accessed
    #   by Crawler#docs after this method returns.
    # @return [Wgit::Document] The last Document crawled.
    def crawl_urls(urls = @urls, &block)
      raise 'No urls to crawl' unless urls

      @docs = []
      doc = nil
      Wgit::Utils.each(urls) { |url| doc = handle_crawl_block(url, &block) }
      doc || @docs.last
    end

    # Crawl the url returning the response Wgit::Document or nil if an error
    # occurs.
    #
    # @param url [Wgit::Url] The URL to crawl.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. False will return nil for such a crawl. If false,
    #   you must also provide a `host:` parameter.
    # @param host [Wgit::Url, String] Specify the host by which
    #   an absolute redirect is determined to be internal or not. Must be
    #   absolute and contain a protocol prefix. For example, a `host:` of
    #   'http://www.example.com' will only allow redirects for Urls with a
    #   `to_host` value of 'www.example.com'.
    # @yield [Wgit::Document] The crawled HTML Document regardless if the
    #   crawl was successful or not. Therefore, the Document#url can be used.
    # @return [Wgit::Document, nil] The crawled HTML Document or nil if the
    #   crawl was unsuccessful.
    def crawl_url(
      url = @urls.first,
      follow_external_redirects: true,
      host: nil
    )
      assert_type(url, Wgit::Url)
      if !follow_external_redirects && host.nil?
        raise 'host cannot be nil if follow_external_redirects is false'
      end

      html = fetch(
        url,
        follow_external_redirects: follow_external_redirects,
        host: host
      )
      url.crawled = true

      doc = Wgit::Document.new(url, html)
      yield(doc) if block_given?

      doc.empty? ? nil : doc
    end

    # Crawls an entire website's HTML pages by recursively going through
    # its internal links. Each crawled Document is yielded to a block.
    #
    # Only redirects to the same host are followed. For example, the Url
    # 'http://www.example.co.uk/how' has a host of 'www.example.co.uk' meaning
    # a link which redirects to 'https://ftp.example.co.uk' or
    # 'https://www.example.com' will not be followed. The only exception to
    # this is the initially crawled url which is allowed to redirect anywhere;
    # it's host is then used for other link redirections on the site, as
    # described above.
    #
    # @param url [Wgit::Url] The base URL of the website to be crawled.
    #   It is recommended that this URL be the index page of the site to give a
    #   greater chance of finding all pages within that site/host.
    # @yield [Wgit::Document] Given each crawled Document/page of the site.
    #   A block is the only way to interact with each crawled Document.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the url could not be
    #   crawled successfully.
    def crawl_site(url = @urls.first, &block)
      assert_type(url, Wgit::Url)

      doc = crawl_url(url, &block)
      return nil if doc.nil?

      host      = url.to_base
      alt_url   = url.end_with?('/') ? url.chop : url + '/'
      crawled   = [url, alt_url]
      externals = doc.external_links
      internals = get_internal_links(doc)

      return doc.external_links.uniq if internals.empty?

      loop do
        crawled.uniq!
        internals.uniq!

        links = internals - crawled
        break if links.empty?

        links.each do |link|
          orig_link = link.dup
          doc = crawl_url(
            link, follow_external_redirects: false, host: host, &block
          )

          crawled.push(orig_link, link) # Push both in case of redirects.
          next if doc.nil?

          internals.concat(get_internal_links(doc))
          externals.concat(doc.external_links)
        end
      end

      externals.uniq
    end

    protected

    # This method calls Wgit::Crawler#resolve to obtain the page HTML, handling
    # any errors that arise and setting the @last_response. Errors or any
    # HTTP response that doesn't return a HTML body will be ignored and nil
    # will be returned; otherwise, the HTML String is returned.
    #
    # @param url [Wgit::Url] The URL to fetch the HTML for.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. False will return nil for such a crawl. If false,
    #   you must also provide a `host:` parameter.
    # @param host [Wgit::Url, String] Specify the host by which
    #   an absolute redirect is determined to be internal or not. Must be
    #   absolute and contain a protocol prefix. For example, a `host:` of
    #   'http://www.example.com' will only allow redirects for Urls with a
    #   `to_host` value of 'www.example.com'.
    # @return [String, nil] The crawled HTML or nil if the crawl was
    #   unsuccessful.
    def fetch(url, follow_external_redirects: true, host: nil)
      response = resolve(
        url,
        follow_external_redirects: follow_external_redirects,
        host: host
      )
      @last_response = response
      response.body.empty? ? nil : response.body
    rescue StandardError => e
      Wgit.logger.debug(
        "Wgit::Crawler#fetch('#{url}') exception: #{e.message}"
      )
      @last_response = nil
      nil
    end

    # The resolve method performs a HTTP GET to obtain the HTML response. The
    # Net::HTTPResponse will be returned or an error raised. Redirects can be
    # disabled by setting `redirect_limit: 0`.
    #
    # @param url [Wgit::Url] The URL to fetch the HTML from.
    # @param redirect_limit [Integer] The number of redirect hops to allow
    #   before raising an error.
    # @param follow_external_redirects [Boolean] Whether or not to follow
    #   an external redirect. If false, you must also provide a `host:`
    #   parameter.
    # @param host [Wgit::Url, String] Specify the host by which
    #   an absolute redirect is determined to be internal or not. Must be
    #   absolute and contain a protocol prefix. For example, a `host:` of
    #   'http://www.example.com' will only allow redirects for Urls with a
    #   `to_host` value of 'www.example.com'.
    # @raise [StandardError] If !url.respond_to? :to_uri or a redirect isn't
    #   allowed.
    # @return [Net::HTTPResponse] The HTTP response of the GET request.
    def resolve(
      url,
      redirect_limit: Wgit::Crawler.default_redirect_limit,
      follow_external_redirects: true,
      host: nil
    )
      raise 'url must respond to :to_uri' unless url.respond_to?(:to_uri)

      redirect_count = 0
      response = nil

      loop do
        response = Net::HTTP.get_response(url.to_uri)
        location = Wgit::Url.new(response.fetch('location', ''))

        break unless response.is_a?(Net::HTTPRedirection)
        yield(url, response, location) if block_given?

        unless location.empty?
          if  !follow_external_redirects &&
              !location.is_relative?(host: host)
            raise "External redirect not allowed - Redirected to: \
'#{location}', which is outside of host: '#{host}'"
          end

          raise 'Too many redirects' if redirect_count >= redirect_limit

          redirect_count += 1

          location = url.to_base.concat(location) if location.is_relative?
          url.replace(location)
        end
      end

      response
    end

    # Returns a doc's internal HTML page links in absolute form; used when
    # crawling a site. Override this method in a subclass to change how a site
    # is crawled; not what is extracted from each page (Document extensions
    # should be used for this purpose instead).
    #
    # @param doc [Wgit::Document] The document from which to extract it's
    #   internal page links.
    # @return [Array<Wgit::Url>] The internal page links from doc.
    def get_internal_links(doc)
      doc.internal_full_links
         .map(&:without_anchor) # Because anchors don't change page content.
         .uniq
         .reject do |link|
        ext = link.to_extension
        ext ? !%w[htm html].include?(ext) : false
      end
    end

    private

    # Add the document to the @docs array for later processing or let the block
    # process it here and now.
    def handle_crawl_block(url, &block)
      if block_given?
        crawl_url(url, &block)
      else
        @docs << crawl_url(url)
        nil
      end
    end

    # Add the url to @urls ensuring it is cast to a Wgit::Url if necessary.
    def add_url(url)
      @urls = [] if @urls.nil?
      @urls << Wgit::Url.new(url)
    end

    alias crawl crawl_urls
    alias crawl_pages crawl_urls
    alias crawl_page crawl_url
    alias crawl_r crawl_site
  end
end
