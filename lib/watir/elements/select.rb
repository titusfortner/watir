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
      selection = {both: both, text: text, value: value, label: label}.select { |_k, v| !v.nil? }
      raise "Can not select by more than one method" if selection.size > 1

      value = selection.values.first

      if value.size > 1 || value.first.is_a?(Array)
        value.flatten.map { |v| select_all_by(selection.keys.first => v) }.first
      else
        select_by(selection).first
      end
    end

    #
    # Uses JavaScript to select the option whose text matches the given string.
    #
    # @param [String, Regexp] str_or_rx
    # @raise [Watir::Exception::NoValueFoundException] if the value does not exist.
    #

    def select!(*str_or_rx)
      number = (str_or_rx.size > 1 || str_or_rx.first.is_a?(Array)) ? :multiple : :single
      str_or_rx.flatten.map { |v| select_by! v, number }.first
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

    def select_by(opts)
      type_check(opts.values.first)
      element = option(opts).wait_until(&:exists?)

      element.click unless element.selected?
      element.stale_in_context? ? '' : element.text
    end

    def select_all_by(opts)
      type_check(opts.values.first)
      elements = find_options(*opts.to_a.flatten)

      selected = selected_options
      elements.each { |e| e.click unless selected.include?(e) }
      elements.first.stale_in_context? ? '' : elements.first.text
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
      else
        raise TypeError, "expected String or Regexp, got #{str_or_rx.inspect}:#{str_or_rx.class}"
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

    def type_check(value)
       return if [String, Numeric, Regexp].any? { |k| value.is_a?(k) }

       msg = "expected String, Number or Regexp, got #{value.inspect}:#{value.class}"
       raise TypeError, msg
    end

    def find_options(how, str_or_rx)
      wait_until do
        found = if how == :both
                  found = options(text: str_or_rx)
                  options(label: str_or_rx) if found.empty?
                else
                  options(how => str_or_rx)
                end
        return found unless found.empty?
      end
    rescue Wait::TimeoutError
      raise_no_value_found(str_or_rx)
    end

    # TODO: Consider locating the Select List before throwing the exception
    def raise_no_value_found(str_or_rx)
      raise NoValueFoundException, "#{str_or_rx.inspect} not found in #{inspect}"
    end
  end # Select

  module Container
    alias select_list select
    alias select_lists selects

    Watir.tag_to_class[:select_list] = Select
  end # Container
end # Watir
