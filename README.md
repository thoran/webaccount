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

`driver_options` is passed to `Selenium::WebDriver.for` as `options:`. It defaults to nil, which is what Selenium itself defaults to, so leaving it alone gets you a stock browser.
```ruby
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless=new')

  MyAccount.new(username: username, password: password, driver_options: options)
```
Or in a sub-class, if every instance should be configured the same way:
```ruby
  class MyAccount < WebAccount
    private

    def default_driver_options
      Selenium::WebDriver::Chrome::Options.new.tap do |options|
        options.add_argument('--headless=new')
      end
    end
  end
```

### Timeouts

There are two, both overridable in a sub-class:

| Method | Default | Waits for |
| --- | --- | --- |
| `default_find_timeout` | 5s | An element on a page which has already loaded. |
| `default_wait_timeout` | 30s | Navigation: a submit, the authentication behind it, and the redirect. |

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
  my_account.shutdown # If necessary it logs out and then kills the selenium session.
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

## Contributing

1. Fork it: https://github.com/thoran/WebAccount/fork
2. Create your feature branch: `git checkout -b my-new-feature`
3. Commit your changes: `git commit -am 'Add some feature'`
4. Push to the branch: `git push origin my-new-feature`
5. Create a new pull request


## License

MIT
