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

  describe "#still_logged_in?" do
    def account_with_page(logout_button_present)
      page = Object.new
      page.define_singleton_method(:element_present?){|how, what| (@asked ||= []) << [how, what]; logout_button_present}
      page.define_singleton_method(:asked){@asked}
      account = WebAccount.new(logout_button_selector: {css: '#logout'})
      account.instance_variable_set(:@driver, page)
      [account, page]
    end

    it "is true, and makes logged_in? true, where the page has the logout button" do
      account, page = account_with_page(true)
      _(account.still_logged_in?).must_equal(true)
      _(account.logged_in?).must_equal(true)
      _(page.asked).must_equal([[:css, '#logout']])
    end

    it "is false, and makes logged_in? false, where the page has not" do
      account, _page = account_with_page(false)
      account.instance_variable_set(:@logged_in, true)
      _(account.still_logged_in?).must_equal(false)
      _(account.logged_in?).must_equal(false)
    end

    it "asks once rather than waiting for the button to appear" do
      account, page = account_with_page(false)
      account.still_logged_in?
      _(page.asked.length).must_equal(1)
    end
  end
end
