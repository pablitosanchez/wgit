require_relative 'url'
require_relative 'document'
require_relative 'utils'
require_relative 'assertable'
require 'net/http' # Requires 'uri'.

module Wgit

  # The Crawler class provides a means of crawling web based URL's, turning
  # their HTML into Wgit::Document's.
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

    # Initializes the Crawler by setting the @urls and @docs.
    #
    # @param urls [*Wgit::Url] The URLs to crawl.
    def initialize(*urls)
      self.[](*urls)
      @docs = []
    end

    # Sets this Crawler's @urls.
    #
    # @param urls [Array<Wgit::Url>] The URLs to crawl.
    def urls=(urls)
      @urls = []
      Wgit::Utils.each(urls) { |url| add_url(url) }
    end

    # Sets this Crawler's @urls.
    #
    # @param urls [*Wgit::Url] The URLs to crawl.
    def [](*urls)
      # If urls is nil then add_url (when called later) will set @urls = []
      # so we do nothing here.
      if not urls.nil?
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
    # @param url [Wgit::Url] A URL to crawl.
    def <<(url)
      add_url(url)
    end

    # Crawls individual urls, not entire sites.
    #
    # @param urls [Array<Wgit::Url>] The URLs to crawl.
    # @yield [Wgit::Document] If provided, the block is given each crawled
    #   Document. Otherwise each doc is added to @docs which can be accessed
    #   by Crawler#docs after this method returns.
    # @return [Wgit::Document] The last Document crawled.
    def crawl_urls(urls = @urls, &block)
      raise "No urls to crawl" unless urls
      @docs = []
      doc = nil
      Wgit::Utils.each(urls) { |url| doc = handle_crawl_block(url, &block) }
      doc ? doc : @docs.last
    end

    # Crawl the url and return the response document or nil.
    #
    # @param url [Wgit::Document] The URL to crawl.
    # @yield [Wgit::Document] The crawled HTML Document regardless if the
    #   crawl was successful or not. Therefore, the Document#url can be used.
    # @return [Wgit::Document, nil] The crawled HTML Document or nil if the
    #   crawl was unsuccessful.
    def crawl_url(url = @urls.first)
      assert_type(url, Wgit::Url)
      markup = fetch(url)
      url.crawled = true
      doc = Wgit::Document.new(url, markup)
      yield(doc) if block_given?
      doc.empty? ? nil : doc
    end

    # Crawls an entire website's HTML pages by recursively going through
    # its internal links. Each crawled web Document is yielded to a block.
    #
    # @param base_url [Wgit::Url] The base URL of the website to be crawled.
    # @yield [Wgit::Document] Given each crawled Document/page of the site.
    #   A block is the only way to interact with each crawled Document.
    # @return [Array<Wgit::Url>, nil] Unique Array of external urls collected
    #   from all of the site's pages or nil if the base_url could not be
    #   crawled successfully.
    def crawl_site(base_url = @urls.first, &block)
      assert_type(base_url, Wgit::Url)

      doc = crawl_url(base_url, &block)
      return nil if doc.nil?

      path = base_url.path.nil? ? '/' : base_url.path
      crawled_urls  = [path]
      external_urls = doc.external_links
      internal_urls = get_internal_links(doc)

      return doc.external_links.uniq if internal_urls.empty?

      loop do
        internal_urls.uniq!

        links = internal_urls - crawled_urls
        break if links.empty?

        links.each do |link|
          doc = crawl_url(Wgit::Url.concat(base_url.to_base, link), &block)
          crawled_urls << link
          next if doc.nil?
          internal_urls.concat(get_internal_links(doc))
          external_urls.concat(doc.external_links)
        end
      end

      external_urls.uniq
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

    # The fetch method performs a HTTP GET to obtain the HTML document.
    # Invalid urls or any HTTP response that doesn't return a HTML body will be
    # ignored and nil will be returned. Otherwise, the HTML is returned.
    def fetch(url)
      response = resolve(url)
      @last_response = response
      response.body.empty? ? nil : response.body
    rescue Exception => ex
      Wgit.logger.debug(
        "Wgit::Crawler#fetch('#{url}') exception: #{ex.message}"
      )
      @last_response = nil
      nil
    end

    # The resolve method performs a HTTP GET to obtain the HTML document.
    # A certain amount of redirects will be followed by default before raising
    # an exception. Redirects can be disabled by setting `redirect_limit: 0`.
    # The Net::HTTPResponse will be returned.
    def resolve(url, redirect_limit: Wgit::Crawler.default_redirect_limit)
      redirect_count = -1
      begin
        raise "Too many redirects" if redirect_count >= redirect_limit
        redirect_count += 1

        response = Net::HTTP.get_response(URI(url))
        location = Wgit::Url.new(response.fetch('location', ''))
        if not location.empty?
          url = location.is_relative? ? url.to_base.concat(location) : location
        end
      end while response.is_a?(Net::HTTPRedirection)
      response
    end

    # Add the url to @urls ensuring it is cast to a Wgit::Url if necessary.
    def add_url(url)
      @urls = [] if @urls.nil?
      @urls << Wgit::Url.new(url)
    end

    # Pull out the doc's internal HTML page links for crawling.
    def get_internal_links(doc)
      doc.
        internal_links_without_anchors.
        reject do |link|
          ext = link.to_extension
          ext ? !['htm', 'html'].include?(ext) : false
        end
    end

    alias :crawl :crawl_urls
    alias :crawl_r :crawl_site
  end
end
