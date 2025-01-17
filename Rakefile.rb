# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'dotenv/tasks'

# To load .env vars into a task below:
# task mytask: :dotenv do
# Things that require .env vars.
# end

desc 'Print help information'
task default: :help

Rake::TestTask.new(:test) do |t|
  t.description = 'Run tests'
  t.libs << 'test'
end

Rake::TestTask.new(:smoke) do |t|
  t.description = 'Run a sub set of tests (as a sanity check)'
  t.libs << 'test'
  t.test_files = FileList[
    'test/test_url.rb',
    'test/test_document.rb',
    'test/test_crawler.rb',
    'test/test_readme_code_examples.rb'
  ]
end

desc 'Print help information'
task :help do
  system 'bundle exec rake -D'
end

desc 'Run the setup script'
task :setup do
  system './bin/setup'
end

desc 'Run the development console'
task :console do
  system './bin/console'
end

desc 'Compile all project Ruby files with warnings.'
task :compile do
  paths = Dir['**/*.rb', '**/*.gemspec', 'bin/console']
  paths.each do |file|
    puts "\nCompiling #{file}..."
    system "ruby -cw #{file}"
  end
end

desc 'Download/update a web page test fixture to test/mock/fixtures'
task :save_page, [:url] do |_t, args|
  system "ruby test/mock/save_page.rb #{args[:url]}"
  puts "Don't forget to mock the page in test/mock/fixtures.rb"
end

desc 'Download/update a web site test fixture to test/mock/fixtures'
task :save_site, [:url] do |_t, args|
  system "ruby test/mock/save_site.rb #{args[:url]}"
  puts "Don't forget to mock the site in test/mock/fixtures.rb"
end

desc 'The SAFE RELEASE task which double checks things ;-)'
task :RELEASE, [:remote] do |_t, args|
  raise unless require_relative 'lib/wgit'
  unless Wgit::CONNECTION_DETAILS.empty?
    raise 'Clear the CONNECTION_DETAILS before releasing the gem'
  end

  puts "Releasing gem version #{Wgit::VERSION}, using the #{args[:remote]} Git remote..."
  confirm "Have you went through the TODO.txt 'Gem Publishing Checklist'?"

  # Tag the repo, build and push the gem to rubygems.org.
  Rake::Task[:release].invoke args[:remote]
end

def confirm(question)
  puts "#{question}  (Y/n) [n]"
  input = STDIN.gets.strip
  exit unless input == 'Y'
end
