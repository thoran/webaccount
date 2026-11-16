# test/webaccount_test.rb

# Notes:
# 1. No browser: Selenium::WebDriver.for is swapped for a stand-in for the length of
#   each example and put back afterwards, so what is asserted is what WebAccount asks
#   of Selenium and what it hands back.
# 2. Driver options are built, not used, so no browser is started for them either.
# 3. Downloads are files made in a temporary directory, with their times set by hand.

require_relative '../lib/webaccount'

require 'fileutils'
require 'minitest/autorun'
require 'tmpdir'
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

    it "is sized to the window size given, whether or not driver options are given" do
      with_driver_factory do |stand_in, calls|
        window = Object.new
        window.define_singleton_method(:resize_to){|width, height| @size = [width, height]}
        window.define_singleton_method(:size){@size}
        manage = Object.new
        manage.define_singleton_method(:window){window}
        stand_in.define_singleton_method(:manage){manage}
        WebAccount.new(window_size: [1280, 800], driver_options: :options).driver
        _(window.size).must_equal([1280, 800])
      end
    end

    it "is left at the browser's own size where none is given" do
      with_driver_factory do |stand_in, calls|
        _(WebAccount.new.driver).must_be_same_as(stand_in)
      end
    end

    it "is made with the browser and driver options given" do
      with_driver_factory do |stand_in, calls|
        WebAccount.new(browser: 'Firefox', driver_options: :options).driver
        _(calls).must_equal([[:firefox, :options]])
      end
    end
  end

  describe "#shutdown" do
    def account_with_browser(logged_in:)
      browser = Object.new
      browser.define_singleton_method(:quit){@quit = true}
      browser.define_singleton_method(:quit?){!!@quit}
      account = WebAccount.new
      account.instance_variable_set(:@driver, browser)
      account.instance_variable_set(:@logged_in, logged_in)
      [account, browser]
    end

    it "logs out, then quits the browser" do
      account, browser = account_with_browser(logged_in: true)
      account.define_singleton_method(:logout){@logged_out = true}
      account.shutdown
      _(account.instance_variable_get(:@logged_out)).must_equal(true)
      _(browser.quit?).must_equal(true)
    end

    it "quits the browser even where logging out fails" do
      account, browser = account_with_browser(logged_in: true)
      account.define_singleton_method(:logout){raise Selenium::WebDriver::Error::TimeoutError}
      _{account.shutdown}.must_raise(Selenium::WebDriver::Error::TimeoutError)
      _(browser.quit?).must_equal(true)
    end

    it "doesn't log out where not logged in" do
      account, browser = account_with_browser(logged_in: false)
      account.define_singleton_method(:logout){raise 'logged out'}
      account.shutdown
      _(browser.quit?).must_equal(true)
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

  describe "page selectors" do
    def account_class(page_selectors)
      Class.new(WebAccount){const_set(:PAGE_SELECTORS, page_selectors)}
    end

    {
      login_page_url: nil,
      login_page_username_field_selector: {name: 'username'},
      login_page_password_field_selector: {name: 'password'},
      login_page_submit_button_selector: {xpath: '//input[@type="submit" and @value="Login"]'},
      logout_button_selector: {xpath: '//input[@type="submit" and @value="Logout"]'},
      logged_out_selector: nil,
    }.each do |name, default|
      describe "##{name}" do
        it "is public, as is its setter" do
          _(WebAccount.public_method_defined?(name)).must_equal(true)
          _(WebAccount.public_method_defined?(:"#{name}=")).must_equal(true)
        end

        it "is WebAccount's own where neither #{name}: nor PAGE_SELECTORS gives one" do
          value = WebAccount.new.public_send(name)
          default ? _(value).must_equal(default) : _(value).must_be_nil
        end

        it "is a sub-class's PAGE_SELECTORS[:#{name}]" do
          _(account_class(name => 'from the sub-class').new.public_send(name)).must_equal('from the sub-class')
        end

        it "is #{name}: over a sub-class's PAGE_SELECTORS" do
          _(account_class(name => 'from the sub-class').new(name => 'given').public_send(name)).must_equal('given')
        end

        it "is the value set, over a sub-class's PAGE_SELECTORS" do
          account = account_class(name => 'from the sub-class').new
          account.public_send(:"#{name}=", 'set')
          _(account.public_send(name)).must_equal('set')
        end
      end
    end
  end

  describe "the names before 0.10.0's" do
    it "are gone" do
      %i{
        username_field_selector password_field_selector
        default_username_field_selector default_password_field_selector
        default_login_page_username_field_selector default_login_page_password_field_selector
        default_login_page_submit_button_selector default_logout_button_selector
        logged_out_xpath logged_out_xpath=
      }.each do |name|
        _(WebAccount.method_defined?(name) || WebAccount.private_method_defined?(name)).must_equal(false)
      end
    end

    it "are logged_out_xpath:, no longer a keyword" do
      _{WebAccount.new(logged_out_xpath: '//div')}.must_raise(ArgumentError)
    end
  end

  describe "#page_selectors" do
    it "is WebAccount's PAGE_SELECTORS, the defaults, where a sub-class gives none" do
      _(WebAccount.new.send(:page_selectors)).must_equal(WebAccount::PAGE_SELECTORS)
    end

    it "is a sub-class's PAGE_SELECTORS merged over WebAccount's, key by key" do
      account_class = Class.new(WebAccount){const_set(:PAGE_SELECTORS, {login_page_url: 'https://subclass.example/login', logout_button_selector: {css: '#logout'}})}
      page_selectors = account_class.new.send(:page_selectors)
      _(page_selectors[:login_page_url]).must_equal('https://subclass.example/login')
      _(page_selectors[:logout_button_selector]).must_equal({css: '#logout'})
      _(page_selectors[:login_page_username_field_selector]).must_equal({name: 'username'})
    end

    it "keeps WebAccount's default where a sub-class's value is nil" do
      account_class = Class.new(WebAccount){const_set(:PAGE_SELECTORS, {login_page_username_field_selector: nil})}
      _(account_class.new.login_page_username_field_selector).must_equal({name: 'username'})
    end

    it "is overridden for every reader, and can keep a parent's values" do
      parent = Class.new(WebAccount){const_set(:PAGE_SELECTORS, {login_page_url: 'https://parent.example/login', logged_out_selector: {id: 'parent'}})}
      child = Class.new(parent){private def page_selectors = super.merge(login_page_url: 'https://child.example/login')}
      _(child.new.login_page_url).must_equal('https://child.example/login')
      _(child.new.logged_out_selector).must_equal({id: 'parent'})
    end
  end

  describe "#login" do
    def account_without_browser(**args)
      account = WebAccount.new(**args)
      account.define_singleton_method(:driver){raise 'a browser was wanted'}
      account
    end

    it "names every missing value at once, before a browser is wanted" do
      error = _{account_without_browser.login}.must_raise(ArgumentError)
      _(error.message).must_equal('login_page_url, username, password are missing.')
    end

    it "names the one missing value" do
      error = _{account_without_browser(login_page_url: 'https://given.example/login', username: 'user').login}.must_raise(ArgumentError)
      _(error.message).must_equal('password is missing.')
    end

    it "takes the username and password given to it as well as to new" do
      error = _{account_without_browser(login_page_url: 'https://given.example/login', username: 'user').login(password: 'secret')}.must_raise(RuntimeError)
      _(error.message).must_equal('a browser was wanted')
    end
  end

  describe "#login_page" do
    def account_with_browser(account)
      browser = Object.new
      browser.define_singleton_method(:get){|url| (@got ||= []) << url}
      browser.define_singleton_method(:got){@got}
      account.instance_variable_set(:@driver, browser)
      [account, browser]
    end

    it "gets login_page_url" do
      account, browser = account_with_browser(WebAccount.new(login_page_url: 'https://given.example/login'))
      account.send(:login_page)
      _(browser.got).must_equal(['https://given.example/login'])
    end
  end

  describe "#logged_out?" do
    def account_with_page(account)
      page = Object.new
      page.define_singleton_method(:element_present?){|how, what| (@asked ||= []) << [how, what]; true}
      page.define_singleton_method(:asked){@asked}
      account.instance_variable_set(:@driver, page)
      [account, page]
    end

    it "looks for logged_out_selector" do
      account, page = account_with_page(WebAccount.new(logged_out_selector: {css: '#given'}))
      _(account.logged_out?).must_equal(true)
      _(page.asked).must_equal([[:css, '#given']])
    end
  end

  describe "#logout" do
    it "names logged_out_selector where there is none, before clicking the logout button" do
      account = WebAccount.new
      account.define_singleton_method(:logout_button){raise 'the logout button was wanted'}
      error = _{account.logout}.must_raise(ArgumentError)
      _(error.message).must_equal('logged_out_selector is missing.')
    end
  end

  describe "#driver_options" do
    def driver_options(**args)
      WebAccount.new(**args).send(:driver_options)
    end

    describe "Chrome" do
      it "is the browser by default" do
        _(driver_options).must_be_instance_of(Selenium::WebDriver::Chrome::Options)
      end

      it "starts with a fresh profile where none is given" do
        _(driver_options(browser: :chrome).args.grep(/--user-data-dir/)).must_be_empty
      end

      it "starts with the profile given, expanded" do
        _(driver_options(browser: :chrome, profile_directory: '~/profile').args).must_include("--user-data-dir=#{File.expand_path('~/profile')}")
      end

      it "masks the automation flags" do
        options = driver_options(browser: :chrome)
        _(options.args).must_include('--disable-blink-features=AutomationControlled')
        _(options.exclude_switches).must_include('enable-automation')
      end

      it "downloads into ~/Downloads by default, without asking, opening nothing" do
        _(driver_options(browser: :chrome).prefs[:download]).must_equal({default_directory: File.expand_path('~/Downloads'), prompt_for_download: false, directory_upgrade: true, extensions_to_open: ''})
      end

      it "saves PDFs rather than showing them" do
        _(driver_options(browser: :chrome).prefs[:plugins]).must_equal({always_open_pdf_externally: true})
      end

      it "has a window by default" do
        _(driver_options(browser: :chrome).args.grep(/headless/)).must_be_empty
      end

      it "is headless where asked" do
        _(driver_options(browser: :chrome, headless: true).args).must_include('--headless=new')
      end

      it "says it's whatever Chrome says by default" do
        _(driver_options(browser: :chrome).args.grep(/--user-agent/)).must_be_empty
      end

      it "says it's the user agent given" do
        _(driver_options(browser: :chrome, user_agent: 'Agent/1.0').args).must_include('--user-agent=Agent/1.0')
      end

      it "downloads into the download directory given, expanded" do
        _(driver_options(browser: :chrome, download_directory: '~/statements').prefs[:download][:default_directory]).must_equal(File.expand_path('~/statements'))
      end
    end

    describe "Firefox" do
      it "is Firefox's options" do
        _(driver_options(browser: 'Firefox')).must_be_instance_of(Selenium::WebDriver::Firefox::Options)
      end

      it "starts with a fresh profile where none is given" do
        _(driver_options(browser: :firefox).args).wont_include('-profile')
      end

      it "starts with the profile given, expanded, in place" do
        _(driver_options(browser: :firefox, profile_directory: '~/profile').args).must_equal(['-profile', File.expand_path('~/profile')])
      end

      it "downloads into ~/Downloads by default, without asking, opening nothing" do
        prefs = driver_options(browser: :firefox).prefs
        _(prefs['browser.download.folderList']).must_equal(2)
        _(prefs['browser.download.dir']).must_equal(File.expand_path('~/Downloads'))
        _(prefs['browser.download.useDownloadDir']).must_equal(true)
        _(prefs['browser.download.always_ask_before_handling_new_types']).must_equal(false)
        _(prefs['browser.download.start_downloads_in_tmp_dir']).must_equal(false)
        _(prefs['browser.download.open_pdf_attachments_inline']).must_equal(false)
        _(prefs['pdfjs.disabled']).must_equal(true)
      end

      it "has a window by default" do
        _(driver_options(browser: :firefox).args).wont_include('-headless')
      end

      it "is headless where asked" do
        _(driver_options(browser: :firefox, headless: true).args).must_include('-headless')
      end

      it "says it's whatever Firefox says by default" do
        _(driver_options(browser: :firefox).prefs).wont_include('general.useragent.override')
      end

      it "says it's the user agent given" do
        _(driver_options(browser: :firefox, user_agent: 'Agent/1.0').prefs['general.useragent.override']).must_equal('Agent/1.0')
      end

      it "downloads into the download directory given, expanded" do
        _(driver_options(browser: :firefox, download_directory: '~/statements').prefs['browser.download.dir']).must_equal(File.expand_path('~/statements'))
      end
    end

    it "is nil for other browsers" do
      _(driver_options(browser: :safari)).must_be_nil
    end

    it "is the driver options given, in place of the defaults" do
      _(driver_options(browser: :firefox, profile_directory: '~/profile', driver_options: :options)).must_equal(:options)
    end
  end

  describe "#download_directory" do
    it "is ~/Downloads by default" do
      _(WebAccount.new.download_directory).must_equal(File.expand_path('~/Downloads'))
    end

    it "is the directory given, expanded" do
      _(WebAccount.new(download_directory: '~/statements').download_directory).must_equal(File.expand_path('~/statements'))
    end
  end

  describe "#wait_for_download" do
    before do
      @download_directory = Dir.mktmpdir
      @since = Time.now - 60
      @account = WebAccount.new(download_directory: @download_directory)
      @account.instance_variable_set(:@download_wait, Selenium::WebDriver::Wait.new(timeout: 0.3, interval: 0.05))
    end

    after do
      FileUtils.rm_rf(@download_directory)
    end

    def download(basename, at: Time.now)
      filename = File.join(@download_directory, basename)
      FileUtils.touch(filename)
      File.utime(at, at, filename)
      filename
    end

    it "waits up to default_download_timeout, rather than default_wait_timeout" do
      account = WebAccount.new
      _(account.send(:default_download_timeout)).must_equal(120)
      _(account.send(:download_wait)).wont_be_same_as(account.send(:driver_wait))
    end

    def wait_for_download(**args)
      @account.send(:wait_for_download, since: @since, **args)
    end

    it "is the newest CSV file since the time given" do
      download('older.csv', at: @since + 10)
      newer = download('newer.csv', at: @since + 20)
      _(wait_for_download).must_equal(newer)
    end

    it "ignores files from before the time given" do
      download('before.csv', at: @since - 10)
      _{wait_for_download}.must_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "ignores files with another extension" do
      download('statement.pdf')
      _{wait_for_download}.must_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "finds the extension given" do
      pdf = download('statement.pdf')
      _(wait_for_download(extension: 'pdf')).must_equal(pdf)
    end

    it "ignores a file whose Chrome .crdownload is still there" do
      download('statement.csv')
      download('statement.csv.crdownload')
      _{wait_for_download}.must_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "ignores a file whose Firefox .part is still there" do
      download('12345678_20261103.csv')
      download('12345678_20261103.Xy-9_aB3.csv.part')
      _{wait_for_download}.must_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "ignores a file whose .part is named after it in full" do
      download('statement.csv')
      download('statement.csv.part')
      _{wait_for_download}.must_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "takes the stem to be the name up to its first dot, as Firefox does" do
      download('statement.2026.csv')
      download('statement.Xy-9_aB3.2026.csv.part')
      _{wait_for_download}.must_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "isn't put off by another file's .part" do
      finished = download('finished.csv', at: @since + 10)
      download('unfinished.csv', at: @since + 20)
      download('unfinished.Xy-9_aB3.csv.part', at: @since + 20)
      _(wait_for_download).must_equal(finished)
    end

    it "waits for the .part to go" do
      finished = download('statement.csv')
      part = download('statement.Xy-9_aB3.csv.part')
      @account.instance_variable_set(:@download_wait, Selenium::WebDriver::Wait.new(timeout: 2, interval: 0.05))
      remover = Thread.new{sleep 0.2; File.delete(part)}
      _(wait_for_download).must_equal(finished)
      remover.join
    end
  end

  describe "#click" do
    def account_with_element(displayed:)
      element = Object.new
      element.define_singleton_method(:displayed?){displayed}
      element.define_singleton_method(:click){@clicked = true}
      element.define_singleton_method(:clicked?){!!@clicked}
      page = Object.new
      page.define_singleton_method(:attempt){|&block| block.call(self)}
      page.define_singleton_method(:execute_script){|script, *args| (@scripts ||= []) << [script, *args]}
      page.define_singleton_method(:scripts){@scripts.to_a}
      account = WebAccount.new
      account.instance_variable_set(:@driver, page)
      account.define_singleton_method(:find){|selector| element}
      [account, page, element]
    end

    it "clicks an element which is displayed" do
      account, page, element = account_with_element(displayed: true)
      account.send(:click, id: 'link')
      _(element.clicked?).must_equal(true)
      _(page.scripts).must_be_empty
    end

    it "clicks an element which isn't displayed by JavaScript" do
      account, page, element = account_with_element(displayed: false)
      account.send(:click, id: 'link')
      _(element.clicked?).must_equal(false)
      _(page.scripts).must_equal([['arguments[0].click();', element]])
    end
  end

  describe "#stale?" do
    it "is false for an element still on the page" do
      element = Object.new
      element.define_singleton_method(:displayed?){true}
      _(WebAccount.new.send(:stale?, element)).must_equal(false)
    end

    it "is true for an element gone from the page" do
      element = Object.new
      element.define_singleton_method(:displayed?){raise Selenium::WebDriver::Error::StaleElementReferenceError}
      _(WebAccount.new.send(:stale?, element)).must_equal(true)
    end
  end
end
