begin
  require 'bundler'
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts 'Run `bundle install` to install missing gems'
  exit e.status_code
end


require 'bundler/gem_tasks'
require 'rubygems'
require 'rake/testtask'

task :default => :test

task :test do |t|
  Dir.glob('./test/*_test.rb').each { |file| require file}
end
