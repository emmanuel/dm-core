module DataMapper
  # an Interceptor class can be provided as an argument to Model#before or #after
  # an Interceptor instance is initialized for each call to before/after
  # 
  #   class Author
  #     include DataMapper::Resource
  # 
  #     property :id,           Serial
  #     property :created_at,   DateTime
  #     property :updated_at,   DateTime
  #     property :destroyed_at, DateTime
  # 
  #     before :create,   Timestamp::Created,   :property => :created_at
  #     before :save,     Timestamp::Updated,   :property => properties[:updated_at]
  #     # this updates model.default_scope in its #bind method:
  #     before :destroy,  Timestamp::Destroyed, :property => :destroyed_at
  #   end
  # 
  #   Author.interceptors # => [<#Timestamp::Created @model=Author, ...>,
  #                             <#Timestamp::Updated @model=Author, ...>,
  #                             <#Timestamp::Destroyed @model=Author, ...>]
  # 
  class Interceptor
    attr_reader :model, :occurrence, :preposition, :options

    # @param [DataMapper::Model] model
    #   the model to which this Interceptor will be bound.
    # @param [Symbol] occurrence
    #   one of [:save, :create, :update, :destroy]
    # @param [Symbol] preposition
    #   one of [:before, :after]
    # @param [Hash] options
    #   any additional options with which to configure the interceptor
    # 
    # @raise ArgumentError
    #   if the method named by @handler_name is not implemented by this class
    # 
    # @api semipublic
    def initialize(model, occurrence, preposition, options = {})
      @model        = model
      @occurrence   = occurrence
      @preposition  = preposition
      @options      = options.dup
      @handler_name = @options[:handler_name] || :"#{@preposition}_#{@occurrence}"

      unless self.respond_to?(@handler_name) && 1 == self.method(@handler_name).arity
        raise ArgumentError, "#{self.class} must implement #{@handler_name} (with an arity of 1)"
      end

      # TODO: check if this reveals the @handler_name in the backtrace
      # else if the backtrace/callstack doesn't reveal the handler name,
      # don't just alias @handler_name to :call, but do something like:
      # 
      #   instance_eval <<-RUBY
      #     def call
      #       #{handler_name}
      #     end
      #   RUBY

      yield(self) if block_given?
      bind
    end

    # subclasses are free to override in order to provide behavior that will
    # run on interceptor init. The implementation of #bind must cause #call
    # to be redefined to something meaningful for this Interceptor instance
    # 
    # For example, Paranoid::DateTime might merge options into model.default_scope
    #   it may also call super to utilize the default provisioning scheme
    def bind
      singleton_class.__send__(:alias_method, :call, @handler_name)
    end

    def call(*)
      raise NotImplementedError, "instantiate #{self.class} to get an implementation."
    end

    # Copy the receiver to be an interceptor for +model+
    # 
    # @param [DataMapper::Model] model
    #   the model to which the receiver should be copied
    # @return [DataMapper::Interceptor]
    # 
    # @api private
    def copy(model)
      self.class.new(model, @occurrence, @preposition, @options)
    end
  end
end
