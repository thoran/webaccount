# WebAccount

## Description

Easily log into web accounts by supplying just a username and password, the URL of the login page, and a few selectors for page elements to a sub-class of WebAccount.

## Installation

Add this line to your application's Gemfile:
```ruby
gem 'webaccount'
```
And then execute:
```shell
$ bundle
```
Or install it yourself as:
```shell
$ gem install webaccount
```

## Usage

### Instantiation

#### 1. With implicit defaults
```ruby
  require 'webaccount'

  class MyAccount < WebAccount; end

  MyAccount.new(username: username, password: password)
  # => #<MyAccount @username=username, @password=password, @login_page_url=nil,
  # @login_page_password_field_selector=nil, @login_page_username_field_selector=nil,
  # @login_page_submit_button_selector=nil,
  # @logout_button_selector=nil, @logged_out_xpath=nil>
```

#### 2. With explicit defaults, then in the comment the ultimate defaults if those values remain nil
```ruby
  require 'webaccount'

  class MyAccount < WebAccount
    PAGE_SELECTORS = {
      login_page_url: nil, # There are no defaults, so something like 'https://mysite.com/login' is required.
      login_page_username_field_selector: nil, # Will default to: {name: 'username'}
      login_page_password_field_selector: nil, # Will default to: {name: 'password'}
      login_page_submit_button_selector: nil, # Will default to: {xpath: '//input[@type="submit" and @value="Login"]'}
      logout_button_selector: nil, # Will default to: {xpath: '//input[@type="submit" and @value="Logout"]'}
      logged_out_xpath: nil, # No default value for this, and logout and shutdown require it.
    }
  end

  MyAccount.new(
    **{username: username, password: password}\
      .merge(MyAccount::PAGE_SELECTORS)
  )
  # => #<MyAccount @username=username, @password=password...>
```

#### 3. With supplied values
```ruby
  require 'webaccount'

  class MyAccount < WebAccount
    PAGE_SELECTORS = {
      login_page_url: 'https://mysite.com/login',
      login_page_username_field_selector: {id: 'username'},
      login_page_password_field_selector: {id: 'password'},
      login_page_submit_button_selector: {xpath: '//button[@type="submit" and @value="Login"]'},
      logout_button_selector: {css: '#button-logout'},
      logged_out_xpath: '//div[@class="logged-out"]',
    }
  end

  MyAccount.new(
    **{username: username, password: password}
      .merge(MyAccount::PAGE_SELECTORS)
  )
  # => #<MyAccount @username=username, @password=password...>
```

### Choosing a browser

`browser` is passed to `Selenium::WebDriver.for`, so it accepts whatever Selenium does: `:chrome`, `:firefox`, `:safari`, `:edge`, `:ie`. It defaults to `:chrome`, and a String or a capitalised Symbol is fine.
```ruby
  MyAccount.new(username: username, password: password, browser: :firefox)
```

### Driver options

For Chrome and Firefox, WebAccount builds the options itself:

- With `profile_directory`, the browser starts with that profile, kept between runs, so that a site sees a returning browser. Without it, the browser gets a fresh temporary profile each time.
- With `download_directory`, which defaults to `~/Downloads`, the browser downloads there without asking where, and opens nothing it downloads. Both save PDFs rather than showing them.
- With `headless: true`, the browser runs without a window.
- With `user_agent`, the browser sends that string in place of its own. Leave it unset unless a site needs it: a fixed string goes out of date, and a user agent that disagrees with the browser actually running is itself a sign of automation.
- Neither browser offers to save passwords.
- Chrome's automation flags are masked. Firefox has no preference that masks `navigator.webdriver`.

```ruby
  MyAccount.new(
    username: username, password: password,
    browser: :firefox,
    profile_directory: '~/.my_account/profile',
    download_directory: '~/statements',
    headless: true,
    window_size: [1280, 800]
  )
```
For any other browser, the options are nil, which is Selenium's own default.

`window_size`, a width and a height, sizes the window once the browser has started, for any browser. A site's layout depends on the window's width, and a narrow window, as a headless browser may start with, can get a mobile layout whose selectors differ.

`driver_options` replaces all of this, apart from `window_size`. It is passed to `Selenium::WebDriver.for` as `options:`.
```ruby
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--lang=en-AU')

  MyAccount.new(username: username, password: password, driver_options: options)
```
Or in a sub-class, if every instance should be configured the same way:
```ruby
  class MyAccount < WebAccount
    private

    def default_driver_options
      default_chrome_options.tap do |options|
        options.add_argument('--lang=en-AU')
      end
    end
  end
```

### Timeouts

There are three, each overridable in a sub-class:

| Method | Default | Waits for |
| --- | --- | --- |
| `default_find_timeout` | 5s | An element on a page which has already loaded. |
| `default_wait_timeout` | 30s | Navigation: a submit, the authentication behind it, and the redirect. |
| `default_download_timeout` | 120s | A download to finish, which takes as long as the file is large. |

```ruby
  class SlowAccount < WebAccount
    private

    def default_wait_timeout
      60
    end
  end
```

### Logging in, out, and shutting down
```ruby
  require 'webaccount'

  class MyAccount < WebAccount; end

  my_account = MyAccount.new(username: username, password: password)
  my_account.login
  my_account.logout
  my_account.shutdown # If necessary it logs out, and then, even if logging out fails, kills the selenium session.
```

### Driving the browser once logged in

`driver` is the logged-in browser, a `Selenium::WebDriver::Driver`, for whatever WebAccount doesn't do itself: fetching pages behind the login, reading them, or taking screenshots of them.
```ruby
  my_account = MyAccount.new(username: username, password: password)
  my_account.login
  my_account.driver.get('https://mysite.com/members/page')
  my_account.driver.page_source
  my_account.driver.save_screenshot('page.png')
  my_account.shutdown
```

`still_logged_in?` says whether the page now showing still has the logout button, at once rather than after waiting, so that something moving from page to page can tell when the session has ended, and log in again:
```ruby
  my_account.driver.get(url)
  my_account.login unless my_account.still_logged_in?
```

### Overriding the login method to customise logins
```ruby
  require 'webaccount'

  class MyAccount < WebAccount
    def login
      # Put custom login code here.
    end
  end
```

### Create new methods for selection and navigation

Prefer `find` over `driver.find_element`: it waits up to `default_find_timeout` for the element, whereas `driver.find_element` raises the moment the element isn't there.
```ruby
  require 'webaccount'

  class MyAccount < WebAccount
    def list_page_link
      find(id: 'list')
    end

    def list_page
      login unless logged_in?
      list_page_link.click
    end
  end

  my_account = MyAccount.new(username: username, password: password)
  my_account.list_page
```

### Waiting for downloads

`wait_for_download` returns the name of the newest file with the given extension (`csv` by default) to appear in `download_directory` since the time given. It waits up to `default_download_timeout` for one, and raises `Selenium::WebDriver::Error::TimeoutError` if none appears. A file only counts once the browser has finished it. Chrome writes `<name>.crdownload` and renames it when it's done. Firefox creates an empty `<name>` straight away and writes into `<stem>.<random>.<extensions>.part` beside it, where the stem is the name up to its first dot.
```ruby
  class MyAccount < WebAccount
    def download_statement
      clicked_at = Time.now
      click(id: 'download')
      wait_for_download(since: clicked_at)
    end
  end
```

### Page helpers

These are private, for use in a sub-class:

| Method | Does |
| --- | --- |
| `click(selector)` | Finds the element afresh on each attempt of `driver.attempt`, so an element replaced by a redrawn page is retried. If the element isn't displayed, for instance a link in a closed menu, it's clicked by JavaScript. |
| `stale?(element)` | Whether the element has gone from the page, for waiting out a page being redrawn. |
| `wait_for(selector)` | Waits up to `default_wait_timeout` for any displayed match. |
| `set_value(element, value)` | Sets the value by JavaScript, so that a date picker or the like doesn't open, and then dispatches a bubbling change event. |

## Contributing

1. Fork it: https://github.com/thoran/webaccount/fork
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request


## License

MIT
