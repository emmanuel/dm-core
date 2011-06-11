# TODO: instead of an Array of Path objects, create a Relationship
# on the fly using :through on the previous relationship, creating a
# chain.  Query::Path could then be a thin wrapper that specifies extra
# conditions on the Relationships, like the target property o match
# on.

module DataMapper
  class Query
    # Path is a vector from a source model through a chain of relationships
    # terminating at a target model. It may optionally include a Property on
    # the target model

    class Path
      # TODO: replace this with BasicObject
      instance_methods.each do |method|
        next if method =~ /\A__/ ||
          %w[ send class dup object_id kind_of? instance_of? respond_to? respond_to_missing? equal? freeze frozen? should should_not instance_variables instance_variable_set instance_variable_get instance_variable_defined? remove_instance_variable extend hash inspect to_s copy_object initialize_dup ].include?(method.to_s)
        undef_method method
      end

      include DataMapper::Assertions
      extend Equalizer

      equalize :relationships, :property

      # @api semipublic
      attr_reader :relationships

      # @api semipublic
      attr_reader :property

      # @api semipublic
      def source_model
        relationships.first.source_model
      end

      # @api semipublic
      def target_model
        relationships.last.target_model
      end

      # @api semipublic
      alias_method :model, :target_model

      # @api semipublic
      def repository_name
        relationships.last.relative_target_repository_name
      end

      (Conditions::Comparison.slugs | [ :not ]).each do |slug|
        class_eval <<-RUBY, __FILE__, __LINE__ + 1
          def #{slug}                                                                                                      # def eql
            #{"raise \"explicit use of '#{slug}' operator is deprecated (#{caller.first})\"" if slug == :eql || slug == :in}  #   raise "explicit use of 'eql' operator is deprecated (#{caller.first})"
            Operator.new(self, #{slug.inspect})                                                                            #   Operator.new(self, :eql)
          end                                                                                                              # end
        RUBY
      end

      # @api public
      def kind_of?(klass)
        super || (defined?(@property) ? @property.kind_of?(klass) : false)
      end

      # @api public
      def instance_of?(klass)
        super || (defined?(@property) ? @property.instance_of?(klass) : false)
      end

      # Used for creating :order options. This technique may be deprecated,
      # so marking as semipublic until the issue is resolved.
      #
      # @api semipublic
      def asc
        # raise NoMethodError unless defined?(@property)
        Operator.new(self, :asc)
      end

      # Used for creating :order options. This technique may be deprecated,
      # so marking as semipublic until the issue is resolved.
      #
      # @api semipublic
      def desc
        # TODO: does a Direction support a Relationship arg?
        # raise NoMethodError unless defined?(@property)
        Operator.new(self, :desc)
      end

      # @api semipublic
      def respond_to?(method, include_private = false)
        super                                                                   ||
        (defined?(@property) && @property.respond_to?(method, include_private)) ||
        target_model_relationships.named?(method)                               ||
        target_model_properties.named?(method)
      end

      # @return [Query::Path]
      #   Path with relationships only, no Property target
      # 
      # TODO: split @property out into a Path::Property subclass
      def canonical
        return self unless defined?(@property)

        if relationships.any?
          Path.new(relationships)
        else
          Path::Empty.new(source_model)
        end
      end

      # @param [Associations::Relationship, Property, Symbol, String] subject
      #   the subject to which the receiver should be extended to include
      # 
      # @return [Query::Path, NilClass]
      #   A new path encompassing the receiver extended to the arg
      #   if the arg is a Relationship, a new path is returned which includes it
      #   if the arg is a Property, a new path is returned which targets it
      #   if the arg is a Symbol or String, it is looked for,
      #     first as a relationship name, second as a property name
      #   If this all fails, nil is returned
      def to(subject)
        case subject
        when Associations::Relationship
          # TODO: don't assume +subject+ relationship is at the end of the path:
          # return a shortened path if the relationship appears in the middle
          Path.new(relationships + [subject])
        when Property
          # TODO: separate this out into Path::Property
          Path.new(relationships, subject)
        when Symbol, String
          if relationship = target_model_relationships[method]
            to(relationship)
          elsif property = target_model_properties[method]
            to(property)
          end
        end
      end

    private

      # @api semipublic
      def initialize(relationships, property = nil)
        @relationships = relationships.to_ary.dup

        # TODO: split this out into a Query::Path::Property subclass
        #   or perhaps a Query::PropertyPath which has-a Query::Path
        if property
          @property = 
            if property.respond_to?(:model) && target_model == property.model
              property
            elsif model_property = target_model_properties[property]
              model_property
            else
              raise(ArgumentError, "Unknown property '#{property}' in #{target_model}")
            end
        end
      end

      def target_model_relationships
        target_model.relationships(repository_name)
      end

      def target_model_properties
        target_model.properties(repository_name)
      end

      # @api semipublic
      def method_missing(method, *args)
        if defined?(@property)
          property.send(method, *args) 
        elsif path = to(method)
          path
        else
          raise NoMethodError, "undefined property or relationship '#{subject}' on #{target_model}"
        end
      end

      class Empty < self
        # Path::Empty is for subjects on the source Model itself,
        # so the target_model and source_model are the same
        attr_reader :model
        alias_method :source_model, :model
        alias_method :target_model, :model

        attr_reader :repository_name

      private

        def initialize(model, property_name = nil)
          super([], property_name)

          @model           = model
          @repository_name = model.repository_name
        end
      end
    end # class Path
  end # class Query
end # module DataMapper
