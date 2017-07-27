module WatirSpec
  class Implementation

    attr_writer :name, :guard_proc, :browser_class
    attr_accessor :browser_args

    def initialize
      @guard_proc = nil
    end

    def browser_class
      @browser_class || raise("browser_class not set")
    end

    def name
      @name || raise("implementation name not set")
    end

    def matches_guard?(args)
      return @guard_proc.call(args) if @guard_proc

      args.include? name
    end

    def matching_guards_in(guards)
      result = []
      guards.each { |args, data| data.each { |d| result << d } if args.empty? || matches_guard?(args) }

      result
    end

    def inspect_args
      hash = browser_args.last
      desired_capabilities = hash.delete(:desired_capabilities)
      caps = desired_capabilities.send(:capabilities)
      string = "driver: #{browser_args.first}\n"
      hash.each { |arg| string << "#{arg.inspect}\n" }
      string << "capabilities:\n"
      caps.each { |k, v| string << "\t#{k}: #{v}\n"}
      hash[:desired_capabilities] = desired_capabilities
      string
    end
  end # Implementation
end # WatirSpec
