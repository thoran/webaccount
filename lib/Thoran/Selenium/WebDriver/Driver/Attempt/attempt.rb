# Thoran/Selenium/WebDriver/Driver/Attempt/attempt.rb
# Thoran::Selenium::WebDriver::Driver::Attempt#attempt

# 20260717
# 0.1.0

# Examples:
# 1. driver.attempt do |driver|
#   driver.get('https://example.com/users/sign_in')
#   enter_username
#   enter_password
#   sign_in
# end

# Changes:
# 1. Yield self, so that the documented block argument is the driver rather than nil.
# 2. Use retry rather than loop/break.
# 3. Re-raise rather than calling quit on @driver, which was never assigned, and exiting the process.
# 4. - Timeout::Error: Nothing in Selenium 4 raises it. Its own timeouts, and those of
#   Selenium::WebDriver::Wait, are Selenium::WebDriver::Error::TimeoutError.
# 5. + The errors a flaky page actually raises, none of which were caught before.
#   Deliberately excluded: Error::InvalidSelectorError and Error::NoSuchDriverError, which
#   are programming and environment errors respectively, so retrying only delays the report.

module Thoran
  module Selenium
    module WebDriver
      module Driver
        module Attempt
          TRANSIENT_ERRORS = [
            ::Selenium::WebDriver::Error::ElementClickInterceptedError,
            ::Selenium::WebDriver::Error::ElementNotInteractableError,
            ::Selenium::WebDriver::Error::NoSuchElementError,
            ::Selenium::WebDriver::Error::StaleElementReferenceError,
            ::Selenium::WebDriver::Error::TimeoutError,
            ::Selenium::WebDriver::Error::UnexpectedAlertOpenError,
            ::Selenium::WebDriver::Error::UnknownError,
          ].freeze

          def attempt(max_attempts = 3)
            attempts = 0
            begin
              yield self
            rescue *TRANSIENT_ERRORS => e
              attempts += 1
              warn "Attempt #{attempts} of #{max_attempts} failed: #{e.class}"
              retry if attempts < max_attempts
              raise
            end
          end
        end
      end
    end
  end
end

module Selenium
  module WebDriver
    class Driver
      include Thoran::Selenium::WebDriver::Driver::Attempt
    end
  end
end
