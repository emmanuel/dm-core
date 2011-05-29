module DataMapper
  module Model
    module Hook
      Model.append_inclusions self

      extend Chainable

      def self.included(model)
        model.send(:include, DataMapper::Hook)
        model.extend Methods
      end

      module Methods
        def inherited(model)
          copy_hooks(model)
          super
        end

        # The interceptors bound to the receiver
        # 
        # @api semipublic
        # 
        # TODO: rename #listeners?
        def interceptors
          @interceptors ||= OrderedSet.new
        end

        # @api public
        def before(target_method, method_or_interceptor = nil, options = {}, &block)
          setup_hook(:before, target_method, method_or_interceptor, options, block) { super }
        end

        # @api public
        def after(target_method, method_or_interceptor = nil, options = {}, &block)
          setup_hook(:after, target_method, method_or_interceptor, options, block) { super }
        end

        # @api private
        def hooks
          @hooks ||= {
            # contemplate subsuming discriminator into a `before :load` interceptor
            # :load     => { :before => [], :after => [] },
            :save     => { :before => [], :after => [] },
            :create   => { :before => [], :after => [] },
            :update   => { :before => [], :after => [] },
            :destroy  => { :before => [], :after => [] },
          }
        end

      private

        # @param [Symbol] type
        #   one of :before or :after
        # @param [Symbol] name
        #   one of :save, :create, :update or :destroy
        # @param [Symbol, DataMapper::Model::Hook::Interceptor] method_or_interceptor
        #   either a method name to call back, or an interceptor that
        #   responds to the specified name/type (occurrence/preposition) pair
        # @param [Hash] options
        #   if +method_or_interceptor+ is a subclass of Interceptor, +options+ will be
        #   passed to +method_or_interceptor#initialize+
        # 
        # @api private
        def setup_hook(type, name, method_or_interceptor, options, proc)
          types = hooks[name]
          if types && types[type]
            types[type] <<
              if method_or_interceptor < DataMapper::Interceptor
                listener = method_or_interceptor.new(self, name, type, options, &proc)
                self.listeners << listener
                listener
              elsif proc
                ProcCommand.new(proc)
              else
                MethodCommand.new(self, method_or_interceptor)
              end
          else
            yield
          end
        end

        # deep copy hooks from the parent model
        # TODO: shouldn't this be an eager copy instead of a lazy one?
        def copy_hooks(model)
          hooks_copy = Hash.new do |hooks, name|
            hooks[name] = Hash.new do |types, type|
              if self.hooks[name]
                types[type] = self.hooks[name][type].map do |command|
                  command.copy(model)
                end
              end
            end
          end

          model.instance_variable_set(:@hooks, hooks_copy)
        end

      end

      class ProcCommand
        def initialize(proc)
          @proc = proc.to_proc
        end

        def call(resource)
          resource.instance_eval(&@proc)
        end

        def copy(model)
          self
        end
      end

      class MethodCommand
        def initialize(model, method)
          @model, @method = model, method.to_sym
        end

        def call(resource)
          resource.__send__(@method)
        end

        def copy(model)
          self.class.new(model, @method)
        end

      end

    end # module Hook
  end # module Model
end # module DataMapper
