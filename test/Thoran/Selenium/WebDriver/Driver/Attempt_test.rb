# test/Thoran/Selenium/WebDriver/Driver/Attempt_test.rb

# Notes:
# 1. selenium-webdriver is required first because attempt.rb resolves the Selenium error
#   classes at load time, in TRANSIENT_ERRORS, but does not require them itself.
# 2. The transient and non-transient errors are listed here rather than read from
#   TRANSIENT_ERRORS, so that these tests state which errors are meant to be retried rather
#   than agreeing with whatever the implementation happens to say.
# 3. No driver, no browser: the errors are raised directly at a dummy including the module.

require 'selenium-webdriver'
require_relative '../../../../../lib/Thoran/Selenium/WebDriver/Driver/Attempt/attempt'

require 'minitest/autorun'
require 'minitest-spec-context'

class AttemptDummy
  include Thoran::Selenium::WebDriver::Driver::Attempt
end

describe Thoran::Selenium::WebDriver::Driver::Attempt do
  TRANSIENT = [
    Selenium::WebDriver::Error::ElementClickInterceptedError,
    Selenium::WebDriver::Error::ElementNotInteractableError,
    Selenium::WebDriver::Error::NoSuchElementError,
    Selenium::WebDriver::Error::StaleElementReferenceError,
    Selenium::WebDriver::Error::TimeoutError,
    Selenium::WebDriver::Error::UnexpectedAlertOpenError,
    Selenium::WebDriver::Error::UnknownError,
  ]

  NON_TRANSIENT = [
    Selenium::WebDriver::Error::InvalidSelectorError,
    Selenium::WebDriver::Error::NoSuchDriverError,
    ArgumentError,
  ]

  before do
    @dummy = AttemptDummy.new
  end

  context "when the block succeeds" do
    it "returns the value of the block" do
      expect(@dummy.attempt{42}).must_equal(42)
    end

    it "yields itself, so that the documented block argument is the receiver" do
      yielded = nil
      @dummy.attempt{|driver| yielded = driver}
      expect(yielded).must_be_same_as(@dummy)
    end

    it "calls the block once" do
      calls = 0
      @dummy.attempt{calls += 1}
      expect(calls).must_equal(1)
    end

    it "says nothing" do
      _out, err = capture_io{@dummy.attempt{42}}
      expect(err).must_be_empty
    end
  end

  context "when the block raises a transient error" do
    TRANSIENT.each do |error_class|
      it "retries #{error_class}" do
        calls = 0
        capture_io do
          @dummy.attempt(3) do
            calls += 1
            raise error_class if calls < 3
          end
        end
        expect(calls).must_equal(3)
      end
    end

    it "returns the value of the attempt which succeeds" do
      calls = 0
      value = nil
      capture_io do
        value = @dummy.attempt(3) do
          calls += 1
          raise Selenium::WebDriver::Error::StaleElementReferenceError if calls < 2
          :recovered
        end
      end
      expect(value).must_equal(:recovered)
    end

    it "re-raises once max_attempts is reached" do
      capture_io do
        expect do
          @dummy.attempt(3){raise Selenium::WebDriver::Error::UnknownError}
        end.must_raise(Selenium::WebDriver::Error::UnknownError)
      end
    end

    it "makes exactly max_attempts attempts before re-raising" do
      calls = 0
      capture_io do
        begin
          @dummy.attempt(3){calls += 1; raise Selenium::WebDriver::Error::UnknownError}
        rescue Selenium::WebDriver::Error::UnknownError
        end
      end
      expect(calls).must_equal(3)
    end

    it "honours a supplied max_attempts" do
      calls = 0
      capture_io do
        begin
          @dummy.attempt(5){calls += 1; raise Selenium::WebDriver::Error::UnknownError}
        rescue Selenium::WebDriver::Error::UnknownError
        end
      end
      expect(calls).must_equal(5)
    end

    it "defaults to three attempts" do
      calls = 0
      capture_io do
        begin
          @dummy.attempt{calls += 1; raise Selenium::WebDriver::Error::UnknownError}
        rescue Selenium::WebDriver::Error::UnknownError
        end
      end
      expect(calls).must_equal(3)
    end

    it "warns once per failed attempt, naming the error" do
      _out, err = capture_io do
        begin
          @dummy.attempt(2){raise Selenium::WebDriver::Error::StaleElementReferenceError}
        rescue Selenium::WebDriver::Error::StaleElementReferenceError
        end
      end
      expect(err.lines.size).must_equal(2)
      expect(err).must_match(/Attempt 1 of 2 failed: Selenium::WebDriver::Error::StaleElementReferenceError/)
      expect(err).must_match(/Attempt 2 of 2 failed: Selenium::WebDriver::Error::StaleElementReferenceError/)
    end
  end

  context "when the block raises a non-transient error" do
    NON_TRANSIENT.each do |error_class|
      it "does not retry #{error_class}" do
        calls = 0
        capture_io do
          expect do
            @dummy.attempt(3){calls += 1; raise error_class}
          end.must_raise(error_class)
        end
        expect(calls).must_equal(1)
      end
    end

    it "says nothing, since it did not retry" do
      _out, err = capture_io do
        begin
          @dummy.attempt(3){raise Selenium::WebDriver::Error::InvalidSelectorError}
        rescue Selenium::WebDriver::Error::InvalidSelectorError
        end
      end
      expect(err).must_be_empty
    end
  end
end
