require 'dm-core/property'

module DataMapper
  class Property::DeprecatedTypeError < ArgumentError
    def initialize(deprecated_type, replacement_type)
      @deprecated_type  = deprecated_type
      @replacement_type = replacement_type
    end

    def message
      "#{deprecated_type} is deprecated, use #{replacement_type} instead"
    end
  end

  class Property::UnsupportedTypeError < ArgumentError
    def initialize(type)
      @type = type
    end

    def message
      "#{type.inspect} is not a supported type"
    end
  end

  module Model
    module Property
      class RepositoryPropertySet
        attr_reader :model
        attr_reader :property_sets

        def initialize(model)
          @model = model
          @property_sets = {}
        end

        def add_property(name, raw_type, options = {})
          assert_supported_type(raw_type)

          # if the type can be found within Property then
          # use that class rather than the primitive
          property_factory = DataMapper::Property.determine_class(raw_type)
          raise Property::UnsupportedTypeError(raw_type) unless property_factory

          property = property_factory.new(model, name, options)
          current_repository_property_set << property

          # Add property to the other mappings as well if current repository
          #   is the default repository
          if current_repository_name == default_repository_name
            add_to_non_default_repositories(property)
          end

          # Add the property to the lazy_loads set for this resources repository
          # only.
          # TODO Is this right or should we add the property to the lazy contexts
          #   of all repositories?
          if property.lazy?
            add_to_lazy_contexts(current_repository_property_set, property, options)
          end

        end

        def [](repository_name)
          # TODO: create PropertySet#copy that will copy the property_set, but assign the
          # new Relationship objects to a supplied repository and model.  dup does not really
          # do what is needed

          # TODO: stop using #to_sym on uncontrolled input
          repository_name = repository_name.to_sym

          @property_sets.fetch(repository_name) do
            @property_sets[repository_name] = new_property_set_for(repository_name)
          end
        end

        def with_descendants(repository_name = default_repository_name)
          properties = properties(repository_name).dup

          descendants.each do |model|
            model.properties(repository_name).each do |property|
              properties << property
            end
          end

          properties
        end

        def concat(other)
          other.property_sets.each do |repository_name, other_property_set|
            # TODO: add PropertySet#concat and do this:
            # self[repository_name].concat(property_set)
            property_set = self[repository_name]
            other_property_set.each { |property| property_set << property }
          end
        end

        def add_to_non_default_repositories(property_factory, name, options)
          non_default_property_sets.each do |other_repository_name, property_set|
            next if property_set.named?(name)

            # make sure the property is created within the correct repository scope
            DataMapper.repository(other_repository_name) do
              property_set << property_factory.new(model, name, options)
            end
          end
        end

        # TODO: move to PropertySet#add_to_lazy_contexts
        def add_to_lazy_contexts(property_set, property, options)
          # TODO: move to Property#lazy_contexts
          context = options.fetch(:lazy, :default)
          context = :default if context == true

          Array(context).each do |context|
            property_set.lazy_context(context) << property
          end
        end

        def new_property_set_for(repository_name)
          if repository_name == default_repository_name
            property_set_factory.new
          else
            @property_sets[default_repository_name].dup
          end
        end

        def current_repository_property_set
          self[current_repository_name]
        end

        def non_default_property_sets
          DataMapper::Ext::Hash.except(@property_sets, default_repository_name)
        end

        def property_set_factory
          PropertySet
        end

        def current_repository_name
          model.repository_name
        end

        def default_repository_name
          model.default_repository_name
        end

        def assert_supported_type(type)
          raise Property::DeprecatedTypeError.new(type, Boolean) if TrueClass  == type
          raise Property::DeprecatedTypeError.new(type, Decimal) if BigDecimal == type
        end

      end # class RepositoryPropertySet
    end # module Property
  end # module Model
end # module DataMapper
