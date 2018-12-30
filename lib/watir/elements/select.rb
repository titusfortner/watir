module Watir
  class Select < HTMLElement
    #
    # Clears all selected options.
    #

    def clear
      raise Exception::Error, 'you can only clear multi-selects' unless multiple?

      selected_options.each(&:click)
    end

    #
    # Returns true if the select list has one or more options where text or label matches the given value.
    #
    # @param [String, Regexp] str_or_rx
    # @return [Boolean]
    #

    def include?(str_or_rx)
      option(text: str_or_rx).exist? || option(label: str_or_rx).exist? || option(value: str_or_rx).exists?
    end

    #
    # Select the option whose text or label matches the given string.
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::NoValueFoundException] if the value does not exist.
    # @return [String] The text of the option selected. If multiple options match, returns the first match.
    #

    def select(*both, text: nil, value: nil, label: nil)
      selection = {both: both, text: text, value: value, label: label}.select do |_k, v|
        !v.nil? && ![v].flatten.empty?
      end
      raise "Can not select by more than one method: #{selection.inspect}" if selection.size > 1

      value = normalize_value(selection.values.first)

      [value].flatten.map { |v| select_by v }.first
    end

    #
    # Select all options whose text or label matches the given string.
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::NoValueFoundException] if the value does not exist.
    # @return [String] The text of the first option selected.
    #

    def select_all(*str_or_rx)
      Watir.logger.deprecate 'Select#select_all', 'Select#select with an Array or multiple parameters',
                             ids: [:select_all]
      select_all_by(*str_or_rx)
    end

    #
    # Uses JavaScript to select the option whose text matches the given string.
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::NoValueFoundException] if the value does not exist.
    #

    def select!(*both, text: nil, value: nil, label: nil)
      selection = {both: both, text: text, value: value, label: label}.select do |_k, v|
        !v.nil? && ![v].flatten.empty?
      end
      raise 'Can not select by more than one method' if selection.size > 1

      value = normalize_value(selection.values.first)

      [value].flatten.map { |v| select_by! v, :multiple }.first
    end

    #
    # Uses JavaScript to select all options whose text matches the given string.
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::NoValueFoundException] if the value does not exist.
    #

    def select_all!(*str_or_rx)
      Watir.logger.deprecate 'Select#select_all!', 'Select#select! with an Array or multiple parameters',
                             ids: [:select_all]
      select!(*str_or_rx)
    end

    #
    # Selects the option(s) whose value attribute matches the given string.
    #
    # @see +select+
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::NoValueFoundException] if the value does not exist.
    # @return [String] The option selected. If multiple options match, returns the first match
    #

    def select_value(value)
      Watir.logger.deprecate '#select_value', '#select directly or with :value keyword',
                             ids: [:select_value]
      select(value: value)
    end

    #
    # Returns true if any of the selected options' text or label matches the given value.
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::UnknownObjectException] if the options do not exist
    # @return [Boolean]
    #

    def selected?(str_or_rx)
      by_text = options(text: str_or_rx)
      return true if by_text.find(&:selected?)

      by_label = options(label: str_or_rx)
      return true if by_label.find(&:selected?)

      return false unless (by_text.size + by_label.size).zero?

      raise(UnknownObjectException, "Unable to locate option matching #{str_or_rx.inspect}")
    end

    #
    # Returns the value of the first selected option in the select list.
    # Returns nil if no option is selected.
    #
    # @return [String, nil]
    #

    def value
      selected_options.first&.value
    end

    #
    # Returns the text of the first selected option in the select list.
    # Returns nil if no option is selected.
    #
    # @return [String, nil]
    #

    def text
      selected_options.first&.text
    end

    # Returns an array of currently selected options.
    #
    # @return [Array<Watir::Option>]
    #

    def selected_options
      element_call { execute_js :selectedOptions, @element }
    end

    private

    def select_by(str_or_rx)
      found = find_options(:value, str_or_rx)

      select_matching(found)
    end

    def select_by!(str_or_rx, number)
      js_rx = process_str_or_rx(str_or_rx)

      %w[Text Label Value].each do |approach|
        element_call { execute_js("selectOptions#{approach}", self, js_rx, number.to_s) }
        return selected_options.first.text if matching_option?(approach.downcase, str_or_rx)
      end

      raise_no_value_found(str_or_rx)
    end

    def process_str_or_rx(str_or_rx)
      case str_or_rx
      when Numeric
        "^#{str_or_rx.to_s}$"
      when String
        "^#{str_or_rx}$"
      when Regexp
        str_or_rx.inspect.sub('\\A', '^')
                 .sub('\\Z', '$')
                 .sub('\\z', '$')
                 .sub(%r{^\/}, '')
                 .sub(%r{\/[a-z]*$}, '')
                 .gsub(/\(\?#.+\)/, '')
                 .gsub(/\(\?-\w+:/, '(')
      end
    end

    def normalize_value(value)
      msg = "expected String, Numeric or Regexp, got #{value.inspect}:#{value.class}"

      case value
      when Array
        raise TypeError, msg if value.empty?

        value.map(&method(:normalize_value))
      when Numeric
        value.to_s
      when String, Regexp
        value
      else
        raise TypeError, msg
      end
    end

    def matching_option?(how, what)
      selected_options.each do |opt|
        value = opt.send(how)
        next unless what.is_a?(String) ? value == what : value =~ what
        return true if opt.enabled?

        raise ObjectDisabledException, "option matching #{what} by #{how} on #{inspect} is disabled"
      end
      false
    end

    def select_all_by(str_or_rx)
      raise Error, 'you can only use #select_all on multi-selects' unless multiple?

      found = find_options :text, str_or_rx

      select_matching(found)
    end

    def find_options(how, str_or_rx)
      wait_while do
        @found = how == :value ? options(value: str_or_rx) : []
        @found = options(text: str_or_rx) if @found.empty?
        @found = options(label: str_or_rx) if @found.empty?
        @found.empty? && Watir.relaxed_locate?
      end
      # TODO: Remove conditional when remove relaxed_locate toggle
      return @found unless @found.empty?

      raise_no_value_found(str_or_rx)
    rescue Wait::TimeoutError
      raise_no_value_found(str_or_rx)
    end

    # TODO: Consider locating the Select List before throwing the exception
    def raise_no_value_found(str_or_rx)
      raise NoValueFoundException, "#{str_or_rx.inspect} not found in #{inspect}"
    end

    def select_matching(elements)
      elements = [elements.first] unless multiple?
      elements.each { |e| e.click unless e.selected? }
      # TODO: this can go back to #exist? after `:stale_exists` deprecation removed
      elements.first.stale? ? '' : elements.first.text
    end
  end # Select

  module Container
    alias select_list select
    alias select_lists selects

    Watir.tag_to_class[:select_list] = Select
  end # Container
end # Watir
