module DataMapper
  module Model
    class PropertyAccessorModule < Module
      attr_reader :inspect

      def initialize(model_name)
        @inspect = "#{model_name}::PropertyAccessorModule"
      end

      # defines the reader method for the property
      #
      # @api private
      def define_property_accessors_for(property)
        name                   = property.name
        reader_visibility      = property.reader_visibility
        writer_visibility      = property.writer_visibility
        instance_variable_name = property.instance_variable_name

        define_property_reader(name, reader_visibility, instance_variable_name)
        define_property_writer(name, writer_visibility)

        if property.kind_of?(DataMapper::Property::Boolean)
          define_property_boolean_query(name, reader_visibility)
        end
      end

      def define_property_reader(name, visibility, instance_variable_name)
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{visibility}

          def #{name}
            return #{instance_variable_name} if defined?(#{instance_variable_name})
            property = properties[:#{name}]
            #{instance_variable_name} = property ? persistence_state.get(property) : nil
          end
        RUBY
      end

      def define_property_boolean_query(name, visibility)
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{visibility}

          def #{name}?
            #{name}
          end
        RUBY
      end

      # defines the setter for the property
      #
      # @api private
      def define_property_writer(name, visibility)
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{visibility}
          def #{name}=(value)
            property = properties[:#{name}]
            self.persistence_state = persistence_state.set(property, value)
            persistence_state.get(property)
          end
        RUBY
      end

    end # class PropertyAccessorModule
  end # module Model
end # module DataMapper
