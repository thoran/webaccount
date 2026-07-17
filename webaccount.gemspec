require_relative './lib/WebAccount/VERSION'

class Gem::Specification
  def dependencies=(gems)
    gems.each{|gem| add_dependency(*gem)}
  end

  def development_dependencies=(gems)
    gems.each{|gem| add_development_dependency(*gem)}
  end
end

Gem::Specification.new do |spec|
  spec.name = 'webaccount'
  spec.version = WebAccount::VERSION

  spec.summary = "An abstract super-class for navigating a web-based user account via Selenium WebDriver."
  spec.description = "Easily log into web accounts by supplying just a username and password, the URL of the login page, and a few page ids to a sub-class of WebAccount."

  spec.author = 'thoran'
  spec.email = 'code@thoran.com'
  spec.homepage = 'http://github.com/thoran/WebAccount'
  spec.license = 'MIT'

  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.3'

  spec.files = [
    'CHANGELOG',
    'Gemfile',
    Dir['lib/**/*.rb'],
    'Rakefile',
    'README.md',
    Dir['test/**/*.rb'],
    'webaccount.gemspec'
  ].flatten

  spec.dependencies = [
    ['selenium-webdriver', '>= 4.0']
  ]

  spec.development_dependencies = %w{
    minitest
    minitest-spec-context
    rake
  }
end
