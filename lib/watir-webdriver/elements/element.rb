# encoding: utf-8

module Watir

  #
  # Base class for HTML elements.
  #

  class Element
    extend AttributeHelper

    include Exception
    include Container
    include EventuallyPresent

    #
    # temporarily add :id and :class_name manually since they're no longer specified in the HTML spec.
    #
    # @see http://html5.org/r/6605
    # @see http://html5.org/r/7174
    #
    # TODO: use IDL from DOM core - http://dvcs.w3.org/hg/domcore/raw-file/tip/Overview.html
    #
    attribute String, :id, :id
    attribute String, :class_name, :className

    def initialize(parent, selector)
      @parent   = parent
      @selector = selector
      @element  = nil

      unless @selector.kind_of? Hash
        raise ArgumentError, "invalid argument: #{selector.inspect}"
      end
    end

    #
    # Returns true if element exists.
    #
    # @return [Boolean]
    #

    def exists?
      assert_exists
      true
    rescue Watir::Exception::UnknownObjectException, Watir::Exception::UnknownFrameException
      false
    end
    alias_method :exist?, :exists?

    def inspect
      if @selector.key?(:element)
        '#<%s:0x%x located=%s selector=%s>' % [self.class, hash*2, !!@element, '{element: (webdriver element)}']
      else
        '#<%s:0x%x located=%s selector=%s>' % [self.class, hash*2, !!@element, selector_string]
      end
    end

    #
    # Returns true if two elements are equal.
    #
    # @example
    #   browser.text_field(name: "new_user_first_name") == browser.text_field(name: "new_user_first_name")
    #   #=> true
    #

    def ==(other)
      other.is_a?(self.class) && wd == other.wd
    end
    alias_method :eql?, :==

    def hash
      @element ? @element.hash : super
    end

    #
    # Returns the text of the element.
    #
    # @return [String]
    #

    def text
      element_call { @element.text }.strip
    end

    #
    # Returns tag name of the element.
    #
    # @return [String]
    #

    def tag_name
      element_call { @element.tag_name.downcase }
    end

    #
    # Clicks the element, optionally while pressing the given modifier keys.
    # Note that support for holding a modifier key is currently experimental,
    # and may not work at all.
    #
    # @example Click an element
    #   browser.element(name: "new_user_button").click
    #
    # @example Click an element with shift key pressed
    #   browser.element(name: "new_user_button").click(:shift)
    #
    # @example Click an element with several modifier keys pressed
    #   browser.element(name: "new_user_button").click(:shift, :control)
    #
    # @param [:shift, :alt, :control, :command, :meta] Modifier key(s) to press while clicking.
    #

    def click(*modifiers)
      element_call(:wait_for_present) do
        assert_enabled

        if modifiers.any?
          assert_has_input_devices_for "click(#{modifiers.join ', '})"

          action = driver.action
          modifiers.each { |mod| action.key_down mod }
          action.click @element
          modifiers.each { |mod| action.key_up mod }

          action.perform
        else
          @element.click
        end
      end

      run_checkers
    end

    #
    # Double clicks the element.
    # Note that browser support may vary.
    #
    # @example
    #   browser.element(name: "new_user_button").double_click
    #

    def double_click
      assert_has_input_devices_for :double_click

      element_call(:wait_for_present) { driver.action.double_click(@element).perform }
      run_checkers
    end

    #
    # Right clicks the element.
    # Note that browser support may vary.
    #
    # @example
    #   browser.element(name: "new_user_button").right_click
    #

    def right_click
      assert_has_input_devices_for :right_click

      element_call(:wait_for_present) { driver.action.context_click(@element).perform }
      run_checkers
    end

    #
    # Moves the mouse to the middle of this element.
    # Note that browser support may vary.
    #
    # @example
    #   browser.element(name: "new_user_button").hover
    #

    def hover
      assert_has_input_devices_for :hover

      element_call { driver.action.move_to(@element).perform }
    end

    #
    # Drag and drop this element on to another element instance.
    # Note that browser support may vary.
    #
    # @example
    #   a = browser.div(id: "draggable")
    #   b = browser.div(id: "droppable")
    #   a.drag_and_drop_on b
    #

    def drag_and_drop_on(other)
      assert_is_element other
      assert_has_input_devices_for :drag_and_drop_on

      element_call do
        driver.action.
            drag_and_drop(@element, other.wd).
            perform
      end
    end

    #
    # Drag and drop this element by the given offsets.
    # Note that browser support may vary.
    #
    # @example
    #   browser.div(id: "draggable").drag_and_drop_by 100, -200
    #
    # @param [Fixnum] right_by
    # @param [Fixnum] down_by
    #

    def drag_and_drop_by(right_by, down_by)
      assert_has_input_devices_for :drag_and_drop_by

      element_call do
        driver.action.
            drag_and_drop_by(@element, right_by, down_by).
            perform
      end
    end

    #
    # Flashes (change background color far a moment) element.
    #
    # @example
    #   browser.text_field(name: "new_user_first_name").flash
    #

    def flash
      background_color = style("backgroundColor")
      element_color = driver.execute_script("arguments[0].style.backgroundColor", @element)

      10.times do |n|
        color = (n % 2 == 0) ? "red" : background_color
        driver.execute_script("arguments[0].style.backgroundColor = '#{color}'", @element)
      end

      driver.execute_script("arguments[0].style.backgroundColor = arguments[1]", @element, element_color)

      self
    end

    #
    # Scrolls to the location of an element in the DOM
    # Returns the resulting location on the screen
    #
    # @example
    #   browser.text_field(id: "scroll_into_view").scroll_to
    #

    def scroll_into_view
      wd.location_once_scrolled_into_view
      self
    end

    #
    # Returns value of the element.
    #
    # @return [String]
    #

    def value
      attribute_value('value') || ''
    rescue Selenium::WebDriver::Error::InvalidElementStateError
      ''
    end

    #
    # Returns given attribute value of element.
    #
    # @example
    #   browser.a(id: "link_2").attribute_value "title"
    #   #=> "link_title_2"
    #
    # @param [String] attribute_name
    # @return [String, nil]
    #

    def attribute_value(attribute_name)
      element_call { @element.attribute attribute_name }
    end

    #
    # Returns outer (inner + element itself) HTML code of element.
    #
    # @example
    #   browser.div(id: 'foo').outer_html
    #   #=> "<div id=\"foo\"><a href=\"#\">hello</a></div>"
    #
    # @return [String]
    #

    def outer_html
      element_call { execute_atom(:getOuterHtml, @element) }.strip
    end

    alias_method :html, :outer_html

    #
    # Returns inner HTML code of element.
    #
    # @example
    #   browser.div(id: 'foo').inner_html
    #   #=> "<a href=\"#\">hello</a>"
    #
    # @return [String]
    #

    def inner_html
      element_call { execute_atom(:getInnerHtml, @element) }.strip
    end

    #
    # Sends sequence of keystrokes to element.
    #
    # @example
    #   browser.text_field(name: "new_user_first_name").send_keys "Watir", :return
    #
    # @param [String, Symbol] *args
    #

    def send_keys(*args)
      element_call(:wait_for_present) do
        assert_writable
        @element.send_keys(*args)
      end
    end

    #
    # Focuses element.
    # Note that Firefox queues focus events until the window actually has focus.
    #
    # @see http://code.google.com/p/selenium/issues/detail?id=157
    #

    def focus
      element_call(:wait_for_present) { driver.execute_script "return arguments[0].focus()", @element }
    end

    #
    # Returns true if this element is focused.
    #
    # @return [Boolean]
    #

    def focused?
      element_call(:wait_for_present) { @element == driver.switch_to.active_element }
    end

    #
    # Simulates JavaScript events on element.
    # Note that you may omit "on" from event name.
    #
    # @example
    #   browser.button(name: "new_user_button").fire_event :click
    #   browser.button(name: "new_user_button").fire_event "mousemove"
    #   browser.button(name: "new_user_button").fire_event "onmouseover"
    #
    # @param [String, Symbol] event_name
    #

    def fire_event(event_name)
      event_name = event_name.to_s.sub(/^on/, '').downcase

      element_call { execute_atom :fireEvent, @element, event_name }
    end

    #
    # Returns parent element of current element.
    #

    def parent
      e = element(xpath: './ancestor::*[1]')
      e.exists? ? e.to_subtype : nil
    end

    #
    # Returns previous sibling element of current element.
    #

    def previous_sibling
      element(xpath: './preceding-sibling::*[1]')
      e.exists? ? e.to_subtype : e
    end

    #
    # Returns following sibling element of current element.
    #

    def next_sibling
      e = element(xpath: './following-sibling::*')
      e.exists? ? e.to_subtype : e
    end

    #
    # @api private
    #

    def driver
      @parent.driver
    end

    #
    # @api private
    #

    def wd
      assert_exists
      @element
    end

    #
    # Returns true if this element is visible on the page.
    # Raises exception if element does not exist
    #
    # @return [Boolean]
    #

    def visible?
      element_call(:assert_exists) { @element.displayed? }
    end

    #
    # Returns true if the element exists and is visible on the page.
    # Returns false if element does not exist or exists but is not visible
    #
    # @return [Boolean]
    # @see Watir::Wait
    #

    def present?
      visible?
    rescue UnknownObjectException
      # Element does not exist
      false
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      # Element goes stale during lookup, and Watir#always_locate? is false
      false
    end

    #
    # Returns given style property of this element.
    #
    # @example
    #   browser.button(value: "Delete").style           #=> "border: 4px solid red;"
    #   browser.button(value: "Delete").style("border") #=> "4px solid red"
    #
    # @param [String] property
    # @return [String]
    #

    def style(property = nil)
      if property
        element_call { @element.style property }
      else
        attribute_value("style").to_s.strip
      end
    end

    #
    # Runs checkers.
    #

    def run_checkers
      @parent.run_checkers
    end

    #
    # Cast this Element instance to a more specific subtype.
    #
    # @example
    #   browser.element(xpath: "//input[@type='submit']").to_subtype
    #   #=> #<Watir::Button>
    #

    def to_subtype
      elem = wd()
      tag_name = elem.tag_name.downcase

      klass = nil

      if tag_name == "input"
        klass = case elem.attribute(:type)
                when *Button::VALID_TYPES
                  Button
                when 'checkbox'
                  CheckBox
                when 'radio'
                  Radio
                when 'file'
                  FileField
                else
                  TextField
                end
      else
        klass = Watir.element_class_for(tag_name)
      end

      klass.new(@parent, element: elem)
    end

    #
    # Returns browser.
    #
    # @return [Watir::Browser]
    #

    def browser
      @parent.browser
    end

    protected

    def wait_for_exists
      return if exists? # Performance shortcut

      assert_element_found unless Watir.always_locate? # don't re-lookup element

      @parent.wait_for_exists # Wait for each element from the top down

      begin
        Watir::Wait.until { exists? }
      rescue Watir::Wait::TimeoutError
        unless Watir.default_timeout == 0
          warn "This test has slept for the duration of the default timeout. "\
                  "If your test is passing, consider using Element#exists? instead of rescuing this error)"
        end
        raise unknown_exception, "unable to locate element, using #{selector_string} "\
                                         "after waiting #{Watir.default_timeout} seconds)"
      end
    end

    def wait_for_present
      return if present? # Performance shortcut

      @parent.wait_for_present
      wait_for_exists
      begin
        Watir::Wait.until { present? }
      rescue Watir::Wait::TimeoutError
        unless Watir.default_timeout == 0
          warn "This test has slept for the duration of the default timeout. "\
                  "If your test is passing, consider using Element#present? instead of rescuing this error)"
        end
        raise unknown_exception, "element located but not visible, using #{selector_string} "\
                                         "after waiting #{Watir.default_timeout} seconds)"
      end
    end

    # Ensure that the element exists, making sure that it is not stale and located if necessary
    def assert_exists
      @element ||= @selector[:element]

      if @element
        ensure_not_stale # ensure not stale
      else
        @element = locate
      end

      assert_element_found
    end

    # Ensure that the element isn't stale, by relocating if it is (unless always_locate = false)
    def ensure_not_stale
      # Performance shortcut; only need recursive call to ensure context if stale in current context
      return unless stale?

      ensure_context
      if stale?
        if Watir.always_locate? && !@selector[:element]
          @element = locate
        else
          reset!
        end
      end
      assert_element_found
    end

    def stale?
      @element.enabled? # any wire call will check for staleness
      false
    rescue Selenium::WebDriver::Error::ObsoleteElementError
      true
    end

    def assert_element_found
      unless @element
        raise unknown_exception, "unable to locate element, using #{selector_string}"
      end
    end

    def reset!
      @element = nil
    end

    def locate
      ensure_context
      locator_class.new(@parent.wd, @selector, self.class.attribute_list).locate
    end

    private

    def unknown_exception
      Watir::Exception::UnknownObjectException
    end

    def locator_class
      ElementLocator
    end

    def selector_string
      @selector.inspect
    end

    # Ensure the driver is in the desired browser context
    def ensure_context
      @parent.is_a?(IFrame) ? @parent.switch_to! : @parent.assert_exists
    end

    def attribute?(attribute)
      element_call do
        !!execute_atom(:getAttribute, @element, attribute.to_s.downcase)
      end
    end

    def assert_enabled
      unless element_call { @element.enabled? }
        raise ObjectDisabledException, "object is disabled #{selector_string}"
      end
    end

    def assert_writable
      assert_enabled

      if respond_to?(:readonly?) && readonly?
        raise ObjectReadOnlyException, "object is read only #{selector_string}"
      end
    end

    def assert_has_input_devices_for(name)
      unless driver.kind_of? Selenium::WebDriver::DriverExtensions::HasInputDevices
        raise NotImplementedError, "#{self.class}##{name} is not supported by this driver"
      end
    end

    def assert_is_element(obj)
      unless obj.kind_of? Watir::Element
        raise TypeError, "execpted Watir::Element, got #{obj.inspect}:#{obj.class}"
      end
    end

    def element_call(exist_check=:wait_for_exists)
      if Watir.always_locate? && [:wait_for_exists, :wait_for_present, :assert_exists].include?(exist_check)
        send exist_check
      else
        assert_exists
      end
      yield
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      raise unless Watir.always_locate?      retry
    end

    def method_missing(meth, *args, &blk)
      method = meth.to_s
      if method =~ ElementLocator::WILDCARD_ATTRIBUTE
        attribute_value(method.gsub(/_/, '-'), *args)
      else
        super
      end
    end

    def respond_to_missing?(meth, *)
      ElementLocator::WILDCARD_ATTRIBUTE === meth.to_s || super
    end

  end # Element
end # Watir
