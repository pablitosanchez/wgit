# frozen_string_literal: true

require_relative 'database_default_data'
require 'mongo'
require 'logger'

module Wgit
  # Helper class for the Database to manipulate data. Used for testing and
  # development. This class isn't packaged in the gem and is for dev only so it
  # doesn't currently have unit tests. This class was originally
  # developed to assist in testing database.rb and is in essence tested by the
  # database tests themselves as they use the helper methods.
  # The main methods include: :clear_db (:nuke), :seed, :index, :search,
  # :num_urls, :num_docs, :num_records
  module DatabaseHelper
    # A connection to the database is established when this module is included.
    def self.included(_base)
      @@client = Database.connect

      @@urls = []
      @@docs = []
    end

    # Returns the number of deleted records.
    def clear_urls
      @@client[:urls].delete_many({}).n
    end

    # Returns the number of deleted records.
    def clear_docs
      @@client[:documents].delete_many({}).n
    end

    # Returns the number of deleted records.
    def clear_db
      clear_urls + clear_docs
    end

    # Seed what's in the block, comprising of url and doc method calls
    # (in this module). If anything other than a hash is given then the default
    # hash is used. An integer can be used to specify how many of default
    # objects should be seeded. One is the default.
    # Returns the number of seeded/inserted documents in the DB.
    # Code example:
    #   seed do
    #     url(url: "http://www.google.co.uk")
    #     doc(url: "https://www.myserver.org", html: "<html></html>")
    #     url 3   # Seeds 3 of the default url records.
    #     doc     # Seeds 1 of the default doc records.
    #   end
    def seed(&block)
      raise 'Must provide a block' unless block_given?

      @@urls.clear
      @@docs.clear

      # &block populates the @@urls and @@docs arrays.
      instance_eval(&block)

      begin
        @@client[:urls].insert_many(@@urls)
        @@client[:documents].insert_many(@@docs)

        @@urls.count + @@docs.count
      rescue StandardError => e
        err_msg = e.message
        err_msg = e.result['writeErrors'] if e.respond_to?(:result)
        raise "Write to DB failed, remember that both urls and docs won't \
accept duplicate urls. Exception details: #{err_msg}"
      end
    end

    # Return if the url_hash/record exists in the DB.
    def url?(url_hash)
      @@client[:urls].find(url_hash).any?
    end

    # Return if the doc_hash/record exists in the DB.
    def doc?(doc_hash)
      @@client[:documents].find(doc_hash).any?
    end

    # Helper method which takes a url and recursively indexes the site storing
    # the markup in the database. Use sensible url's, not www.amazon.com etc.
    def index_site(url, insert_externals = true)
      Wgit.index_this_site url, insert_externals
    end

    # Helper method which crawls a url storing its markup in the database.
    def index_page(url, insert_externals = true)
      Wgit.index_this_page url, insert_externals
    end

    # Searches the database Document collection for the given query, formats
    # and pretty prints the results to the command line. Mainly used for
    # ./bin/console.
    def search(query)
      Wgit.indexed_search query
    end

    # Returns the number of url collection records in the DB.
    def num_urls
      @@client[:urls].count
    end

    # Returns the number of document collection records in the DB.
    def num_docs
      @@client[:documents].count
    end

    # Returns the number of url and document collection records in the DB.
    def num_records
      num_urls + num_docs
    end

    private

    # DSL method used within the block passed to DatabaseHelper#seed.
    # Seeds a Url into the DB.
    def url(hashes_or_int = 1)
      if hashes_or_int && hash_or_array?(hashes_or_int)
        if hashes_or_int.is_a?(Hash)
          @@urls << hashes_or_int
        else
          @@urls.concat(hashes_or_int)
        end
      else
        hashes_or_int.times { @@urls << Wgit::DatabaseDefaultData.url }
      end
    end

    # DSL method used within the block passed to DatabaseHelper#seed.
    # Seeds a Document into the DB.
    def doc(hashes_or_int = 1)
      if hashes_or_int && hash_or_array?(hashes_or_int)
        if hashes_or_int.is_a?(Hash)
          @@docs << hashes_or_int
        else
          @@docs.concat(hashes_or_int)
        end
      else
        hashes_or_int.times { @@docs << Wgit::DatabaseDefaultData.doc }
      end
    end

    # Returns whether or not the obj is a Hash or Array instance.
    def hash_or_array?(obj)
      obj.is_a?(Hash) || obj.is_a?(Array)
    end

    alias nuke clear_db
    alias clear_documents clear_docs
    alias document? doc?
    alias document doc
    alias urls url
    alias docs doc
    alias num_objects num_records
    alias index index_site
  end
end
