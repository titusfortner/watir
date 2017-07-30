module Watir
  module UserEditable

    #
    # Clear the element, the type in the given value.
    #
    # @param [String, Symbol] *args
    #

    def set(*args)
      Watir.executor.go(self) do
        @element.clear
        @element.send_keys(*args)
      end
    end
    alias_method :value=, :set

    #
    # Appends the given value to the text in the text field.
    #
    # @param [String, Symbol] *args
    #

    def append(*args)
      send_keys(*args)
    end
    alias_method :<<, :append

    #
    # Clears the text field.
    #

    def clear
      Watir.executor.go(self) { @element.clear }
    end

  end # UserEditable
end # Watir
