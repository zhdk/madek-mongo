source 'http://rubygems.org'

gem 'rails', '3.1.1.rc2'

gem 'mongoid', '~> 2.2' #tmp# , :git => "git://github.com/mongoid/mongoid.git", :branch => "2.2.0-stable"
gem 'bson_ext', '~> 1.4'

gem 'mongoid_search', '~> 0.2.7' # alternatives: 'mongoid_fulltext' (indexing methods), 'mongoid_text_search', 'mongoid-fulltextable'
gem 'mongoid-tree', '~> 0.6.1', :require => 'mongoid/tree' # alternatives: 'mongoid_acts_as_tree', 'mongoid_nested_set'
#old# gem 'mongoid_identity_map', '~> 0.4.0' #tmp# TODO remove when integrated into mongoid

# Asset template engines
gem 'json', '~> 1.6'
gem 'haml', '~> 3.1'
gem 'sass', '~> 3.1'
gem 'coffee-script', '~> 2.2'
gem 'jquery-rails', '~> 1.0'

# Gems used only for assets and not required in production environments by default.
group :assets do
  gem 'sass-rails', '~> 3.1'
  gem 'coffee-rails', '~> 3.1'
  gem 'uglifier', '~> 1.0'
end

gem 'cancan', '~> 1.6.7'

gem 'kaminari', '~> 0.12.4'
gem 'rails_autolink', '~> 1.0.2'

gem 'zencoder', '~> 2.3.1'
gem 'uuidtools', '~> 2.1.2'
gem 'mini_exiftool', '~> 1.3.1'
gem 'mini_magick', '~> 3.3'

group :test, :development do
  gem 'pry' #gem 'ruby-debug19', '~> 0.11.6', :require => 'ruby-debug'
  gem 'cucumber'
  gem 'cucumber-rails'
  gem 'capybara'
  gem 'selenium-webdriver'
  gem 'rspec-rails'
  gem 'launchy'
  gem "factory_girl_rails", "~> 1.2"
  gem "factory_girl", "~> 2.1.0"
  gem 'faker'
end
