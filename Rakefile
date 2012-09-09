require File.join(File.dirname(__FILE__),"zinc")
namespace :db do 
  task :environment do
    MIGRATIONS_DIR = ENV['MIGRATIONS_DIR'] || PATHS[:migrate]
  end

  desc 'Migrate the database (options: VERSION=x, VERBOSE=false).'
  task :migrate do
    ActiveRecord::Migration.verbose = true
    ActiveRecord::Migrator.migrate MIGRATIONS_DIR, ENV['VERSION'] ? ENV['VERSION'].to_i : nil
  end

  desc 'Rolls the schema back to the previous version (specify steps w/ STEP=n).'
  task :rollback do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1
    ActiveRecord::Migrator.rollback MIGRATIONS_DIR, step
  end

  desc "Retrieves the current schema version number"
  task :version do
    puts "Current version: #{ActiveRecord::Migrator.current_version}"
  end
end
