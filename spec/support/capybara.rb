# Capybara configuration for system tests
RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end
end

# Capybara server configuration
Capybara.server = :puma, { Silent: true }
