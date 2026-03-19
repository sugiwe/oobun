source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

# Active Storage validations [https://github.com/igorkasyanchuk/active_storage_validations]
gem "active_storage_validations"

# Use Slim for templates [https://github.com/slim-template/slim-rails]
gem "slim-rails"

# Google OAuth authentication [https://github.com/googleapis/google-auth-library-ruby]
gem "googleauth"

# ZIP file creation [https://github.com/rubyzip/rubyzip]
gem "rubyzip"

# Pagination [https://github.com/kaminari/kaminari]
gem "kaminari"

# Markdown rendering [https://github.com/vmg/redcarpet]
gem "redcarpet"

# HTML sanitization [https://github.com/rgrove/sanitize]
gem "sanitize"

group :development, :test do
  # RSpec for testing [https://github.com/rspec/rspec-rails]
  gem "rspec-rails", "~> 8.0"

  # Factory Bot for test data creation [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails"

  # Faker for generating fake data [https://github.com/faker-ruby/faker]
  gem "faker"

  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :test do
  # Shoulda Matchers for RSpec [https://github.com/thoughtbot/shoulda-matchers]
  gem "shoulda-matchers", "~> 6.0"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end
