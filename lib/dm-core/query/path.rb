# TODO: instead of an Array of Path objects, create a Relationship
# on the fly using :through on the previous relationship, creating a
# chain.  Query::Path could then be a thin wrapper that specifies extra
# conditions on the Relationships, like the target property o match
# on.

module DataMapper
  class Query
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
      attr_reader :repository_name

      # @api semipublic
      attr_reader :relationships

      # @api semipublic
      attr_reader :source_model

      # @api semipublic
      attr_reader :target_model

      # @api semipublic
      alias_method :model, :target_model

      # @api semipublic
      attr_reader :property

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
        Operator.new(self, :asc)
      end

      # Used for creating :order options. This technique may be deprecated,
      # so marking as semipublic until the issue is resolved.
      #
      # @api semipublic
      def desc
        Operator.new(self, :desc)
      end

      # @api semipublic
      def respond_to?(method, include_private = false)
        super                                                                   ||
        (defined?(@property) && @property.respond_to?(method, include_private)) ||
        target_model_relationships.named?(method)                               ||
        target_model_properties.named?(method)
      end

      def wrap(subject)
        case subject
        when Associations::Relationship
          Path.new(relationships + [subject])
        when Property
          Path.new(relationships, subject.name)
        when Symbol, String
          send(subject)
        end
      end

    private

      # @api semipublic
      def initialize(relationships, property_name = nil)
        @relationships = relationships.to_ary.dup

        first_relationship = @relationships.first
        @source_model      = first_relationship.source_model

        last_relationship = @relationships.last
        @repository_name  = last_relationship.relative_target_repository_name
        @target_model     = last_relationship.target_model

        set_property(property_name)
      end

      def set_property(property_name)
        if property_name
          property_name = property_name.to_sym
          @property = target_model_properties[property_name] ||
            raise(ArgumentError, "Unknown property '#{property_name}' in #{@target_model}")
        end
        self
      end

      def target_model_relationships
        @target_model.relationships(@repository_name)
      end

      def target_model_properties
        @target_model.properties(@repository_name)
      end

      # @api semipublic
      def method_missing(method, *args)
        if @property
          return @property.send(method, *args)
        end

        path_class = self.class

        if relationship = target_model_relationships[method]
          return path_class.new(@relationships.dup << relationship)
        end

        if target_model_properties.named?(method)
          return path_class.new(@relationships, method)
        end

        raise NoMethodError, "undefined property or relationship '#{method}' on #{@target_model}"
      end

      class Empty < self
        # Path::Empty is for subjects on the source Model itself,
        # so the target_model and source_model are the same
        alias_method :source_model, :target_model

      private

        def initialize(model, property_name = nil)
          @relationships   = []
          @target_model    = model
          @repository_name = model.repository_name

          set_property(property_name)
        end
      end
    end # class Path
  end # class Query
end # module DataMapper
