require_relative 'helpers/test_helper'

# Test class for testing the Indexer methods.
# WARNING: The DB is cleared down prior to each test run.
class TestIndexer < TestHelper
  include Wgit::DatabaseHelper

  # Runs before every test.
  def setup
    clear_db

    @db = Wgit::Database.new
  end

  def test_initialize
    indexer = Wgit::Indexer.new @db

    assert_instance_of Wgit::Indexer, indexer
    assert_instance_of Wgit::Crawler, indexer.crawler
    assert_instance_of Wgit::Database, indexer.db
  end

  def test_index_the_web__one_site
    url_str = 'https://motherfuckingwebsite.com/'
    seed { url url: url_str, crawled: false }

    # Index only one site.
    Wgit.index_the_web 1

    # Assert that url.crawled gets updated.
    refute url? url: url_str, crawled: false
    assert url? url: url_str, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    # The orig url and its doc plus plus an external url.
    assert_equal 2, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_the_web__two_sites
    url_str = 'https://motherfuckingwebsite.com/'
    seed { url url: url_str, crawled: false }

    # Index two sites.
    Wgit.index_the_web 2

    # Assert that url.crawled gets updated.
    refute url? url: url_str, crawled: false
    assert url? url: url_str, crawled: true

    # Assert that some indexed docs were inserted into the DB.
    assert_equal 10, @db.num_urls
    assert_equal 8, @db.num_docs
  end

  def test_index_the_web__max_data
    url_str = 'https://motherfuckingwebsite.com/'
    seed { url url: url_str, crawled: false }

    # Index nothing because max_data_size is zero.
    Wgit.index_the_web(-1, 0)

    # Assert nothing was indexed. The only DB record is the original url.
    refute url? url: url_str, crawled: true
    assert url? url: url_str, crawled: false
    assert_equal 1, @db.num_records
  end

  def test_index_this_site__without_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the site and don't insert the external urls.
    Wgit.index_this_site url, false

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_this_site__with_externals
    url = 'https://motherfuckingwebsite.com/'
    num_pages_crawled = 0

    refute url? url: url

    # Index the site and don't insert the external urls.
    Wgit.index_this_site url do |doc|
      assert_instance_of Wgit::Document, doc
      num_pages_crawled += 1
      true # To insert the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, @db.num_urls
    assert_equal 1, @db.num_docs
    assert_equal 1, num_pages_crawled
  end

  def test_index_this_site__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the site and don't insert the external urls.
    Wgit.index_this_site url, false do |doc|
      assert_instance_of Wgit::Document, doc
      false # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 0, @db.num_docs
  end

  def test_index_this_page__without_externals
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and don't insert the external urls.
    Wgit.index_this_page url, false

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_this_page__with_externals
    url = 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and insert the external urls.
    Wgit.index_this_page url

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url and one external url.
    assert_equal 2, @db.num_urls
    assert_equal 1, @db.num_docs
  end

  def test_index_this_page__no_doc_insert
    # Test that returning nil/false from the block prevents saving the doc to
    # the DB.
    url = Wgit::Url.new 'https://motherfuckingwebsite.com/'

    refute url? url: url

    # Index the page and don't insert the external urls.
    Wgit.index_this_page url, false do |doc|
      assert_instance_of Wgit::Document, doc
      false # To avoid inserting the doc into the DB.
    end

    # Assert that url.crawled gets updated.
    assert url? url: url, crawled: true

    # The site has one doc plus its url.
    assert_equal 1, @db.num_urls
    assert_equal 0, @db.num_docs
  end

  def test_indexed_search
    # Because this is a convienence method, the search and format have been
    # tested in Database and Utils; so we just check it runs without error.
    assert_nil Wgit.indexed_search 'abcdefghijklmnopqrstuvwxyz'
  end
end
