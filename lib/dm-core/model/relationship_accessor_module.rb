module DataMapper
  module Model
    class RelationshipAccessorModule < Module
      attr_reader :inspect

      def initialize(model_name)
        @inspect = "#{model_name}::RelationshipAccessorModule"
      end

      # Dynamically defines reader method
      #
      # @api private
      def define_relationship_accessors_for(relationship)
        name = relationship.name

        define_relationship_reader(name, relationship.reader_visibility)
        define_relationship_writer(name, relationship.writer_visibility)
      end

      # Dynamically defines reader method
      #
      # @api private
      def define_relationship_reader(name, visibility)
        # TODO: when no query is passed in, return the results from
        #       the ivar directly. This will require that the ivar
        #       actually hold the resource/collection, and in the case
        #       of 1:1, the underlying collection is hidden in a
        #       private ivar, and the resource is in a known ivar

        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{visibility}

          def #{name}(query = nil)
            persistence_state.get(relationships[:#{name}], query)
          end
        RUBY
      end

      # Dynamically defines writer method
      #
      # @api private
      def define_relationship_writer(name, visibility)
        module_eval <<-RUBY, __FILE__, __LINE__ + 1
          #{visibility}

          def #{name}=(target)
            relationship = relationships[:#{name}]
            self.persistence_state = persistence_state.set(relationship, target)
            persistence_state.get(relationship)
          end
        RUBY
      end

    end # class RelationshipAccessorModule
  end # module Model
end # module DataMapper
