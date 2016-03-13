require File.expand_path("../spec_helper", __FILE__)

class ImplementationConfig
  def initialize(imp)
    @imp = imp
  end

  def configure
    set_webdriver
    start_remote_server if remote? && !ENV["REMOTE_SERVER_URL"]
    set_browser_args
    set_guard_proc
    add_html_routes

    WatirSpec.always_use_server = mobile? || ie? || safari? || phantomjs? || remote?
  end

  private

  def start_remote_server
    require 'selenium/server'

    @server ||= Selenium::Server.new(remote_server_jar,
                                     :port       => Selenium::WebDriver::PortProber.above(4444),
                                     :log        => !!$DEBUG,
                                     :background => true,
                                     :timeout    => 60)

    if remote_browser == :marionette
      @server << "-Dwebdriver.marionette.driver=true"
    end

    @server.start
    at_exit { @server.stop }
  end

  def remote_server_jar
    if File.exist?(ENV['REMOTE_SERVER_BINARY'] || '')
      ENV['REMOTE_SERVER_BINARY']
    elsif !Dir.glob('selenium-server-standalone*.jar').empty?
      Dir.glob('selenium-server-standalone*.jar').first
    else
      Selenium::Server.download :latest
    end
  rescue SocketError
    # not connected to internet
    raise Watir::Exception::Error, "unable to find or download selenium-server-standalone jar"
  end

  def set_webdriver
    @imp.name          = :webdriver
    @imp.browser_class = Watir::Browser
  end

  def set_browser_args
    args = case browser
           when :firefox
             firefox_args
           when :marionette
             marionette_args
           when :chrome
             chrome_args
           when :remote
             remote_args
           else
             [browser, {}]
           end

    if ENV['SELECTOR_STATS']
      listener = SelectorListener.new
      args.last.merge!(listener: listener)
      at_exit { listener.report }
    end

    @imp.browser_args = args
  end

  def mobile?
    [:android, :iphone].include? browser
  end

  def ie?
    [:internet_explorer].include? browser
  end

  def safari?
    browser == :safari
  end

  def phantomjs?
    browser == :phantomjs
  end

  def remote?
    browser == :remote
  end

  def set_guard_proc
    matching_guards = [:webdriver]

    if remote?
      matching_browser = remote_browser
      matching_guards << :remote
      matching_guards << [:remote, matching_browser]
    else
      matching_browser = browser
    end

    # Remote can't verify version due to: https://github.com/SeleniumHQ/selenium/issues/1150
    browser_instance = WatirSpec.new_browser unless remote_browser == :marionette
    browser_version = browser_instance.driver.capabilities.version if browser_instance

    matching_browser_with_version = "#{browser}#{browser_version}".to_sym if browser_version
    matching_guards << matching_browser_with_version if browser_version if browser_version
    matching_guards << [:webdriver, matching_browser_with_version] if browser_version

    matching_guards << matching_browser
    matching_guards << [:webdriver, matching_browser]
    matching_guards << [matching_browser, Selenium::WebDriver::Platform.os]

    if !Selenium::WebDriver::Platform.linux? || ENV['DESKTOP_SESSION']
      # some specs (i.e. Window#maximize) needs a window manager on linux
      matching_guards << [:webdriver, matching_browser, :window_manager]
      matching_guards << [:webdriver, matching_browser_with_version, :window_manager] if browser_version
    end

    @imp.guard_proc = lambda { |args|
      args.any? { |arg| matching_guards.include?(arg) }
    }
  ensure
    browser_instance.close if browser_instance
  end

  def firefox_args
    caps = Selenium::WebDriver::Remote::Capabilities.firefox(firefox_binary: ENV['FIREFOX_BINARY'])

    [:firefox, {desired_capabilities: caps}]
  end

  def marionette_args
    caps = Selenium::WebDriver::Remote::Capabilities.firefox(:firefox_binary => ENV['FIREFOX_BINARY'])
    [:marionette, {desired_capabilities: caps, marionette: true}]
  end

  def chrome_args
    opts = {
      args: ["--disable-translate"]
    }

    if url = ENV['WATIR_WEBDRIVER_CHROME_SERVER']
      opts[:url] = url
    end

    if driver = ENV['WATIR_WEBDRIVER_CHROME_DRIVER']
      Selenium::WebDriver::Chrome.driver_path = driver
    end

    if path = ENV['WATIR_WEBDRIVER_CHROME_BINARY']
      Selenium::WebDriver::Chrome.path = path
    end

    if ENV['TRAVIS']
      opts[:args] << "--no-sandbox" # https://github.com/travis-ci/travis-ci/issues/938
    end

    [:chrome, opts]
  end

  def remote_args
    url = ENV["REMOTE_SERVER_URL"] || "http://127.0.0.1:#{@server.port}/wd/hub"
    caps = if remote_browser == :marionette
             Selenium::WebDriver::Remote::Capabilities.firefox(marionette: true)
           else
             Selenium::WebDriver::Remote::Capabilities.send(@remote_browser)
           end
    [:remote, {url: url, desired_capabilities: caps}]
  end

  def add_html_routes
    glob = File.expand_path("../html/*.html", __FILE__)
    Dir[glob].each do |path|
      WatirSpec::Server.get("/#{File.basename path}") { File.read(path) }
    end
  end

  def browser
    @browser ||= (ENV['WATIR_WEBDRIVER_BROWSER'] || :firefox).to_sym
  end

  def remote_browser
    @remote_browser ||= (ENV['REMOTE_BROWSER'] || :firefox).to_sym
  end

  class SelectorListener < Selenium::WebDriver::Support::AbstractEventListener
    def initialize
      @counts = Hash.new(0)
    end

    def before_find(how, what, driver)
      @counts[how] += 1
    end

    def report
      total = @counts.values.inject(0) { |mem, var| mem + var }
      puts "\nWebDriver selector stats: "
      @counts.each do |how, count|
        puts "\t#{how.to_s.ljust(20)}: #{count * 100 / total} (#{count})"
      end
    end

  end
end

ImplementationConfig.new(WatirSpec.implementation).configure
