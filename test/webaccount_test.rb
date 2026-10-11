# test/webaccount_test.rb

# Notes:
# 1. No browser: Selenium::WebDriver.for is swapped for a stand-in for the length of
#   each example and put back afterwards, so what is asserted is what WebAccount asks
#   of Selenium and what it hands back.

require_relative '../lib/webaccount'

require 'minitest/autorun'
require 'minitest-spec-context'

describe WebAccount do
  def with_driver_factory(&block)
    calls = []
    stand_in = Object.new
    original = Selenium::WebDriver.method(:for)
    Selenium::WebDriver.define_singleton_method(:for){|browser, options: nil| calls << [browser, options]; stand_in}
    block.call(stand_in, calls)
  ensure
    Selenium::WebDriver.define_singleton_method(:for, original)
  end

  describe "#driver" do
    it "is public, so that the logged-in browser can be driven from outside" do
      _(WebAccount.public_method_defined?(:driver)).must_equal(true)
    end

    it "is the browser Selenium made, made once" do
      with_driver_factory do |stand_in, calls|
        account = WebAccount.new
        _(account.driver).must_be_same_as(stand_in)
        _(account.driver).must_be_same_as(stand_in)
        _(calls.length).must_equal(1)
      end
    end

    it "is made with the browser and driver options given" do
      with_driver_factory do |stand_in, calls|
        WebAccount.new(browser: 'Firefox', driver_options: :options).driver
        _(calls).must_equal([[:firefox, :options]])
      end
    end
  end
end
