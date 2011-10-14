ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'

# TODO run as:
# $ rake test:units => doesn't work now 
# use instead => $ find test/unit/ -name "*.rb" -exec ruby -Itest {} \;

# TODO running autotest

# TODO clean database before test
def clean_mongodb
  puts "cleaning mongodb...."
  Mongoid.database.collections.each do |collection|
    unless collection.name =~ /^system\./
      collection.remove
    end
  end
  puts "finished cleaning mongodb."
end
clean_mongodb