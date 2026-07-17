# Thoran/Selenium/WebDriver/Driver/ElementPresentQ/element_presentQ.rb
# Thoran::Selenium::WebDriver::Driver::ElementPresentQ#element_present?

# 20260717
# 0.1.0

# Examples:
# 1. driver.element_present?(:xpath, '//a[@id="submit"]')
# 2. driver.element_present?(:css, '#button-logout')

# Changes:
# 1. Use the public find_elements() rather than the private bridge.
# 2. ^Driver, alongside Driver::Attempt, since this patches Driver too. Selenium's
#   SearchContext is the find_element()/find_elements() contract, which Driver, Element,
#   and ShadowRoot implement, rather than a home for conveniences built on top of it.

module Thoran
  module Selenium
    module WebDriver
      module Driver
        module ElementPresentQ
          def element_present?(selector_type, selector)
            !find_elements(selector_type, selector).empty?
          end
        end
      end
    end
  end
end

module Selenium
  module WebDriver
    class Driver
      include Thoran::Selenium::WebDriver::Driver::ElementPresentQ
    end
  end
end
