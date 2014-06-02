module FortyFacets
  # Base class for the objects representing a specific value for a specific
  # type of filter. Most FilterDefinitions will have their own Filter subclass
  # to control values for display and rendering to request parameters.
  Filter = Struct.new(:filter_definition, :search_instance, :value) do
    def name
      filter_definition.options[:name] || filter_definition.model_field
    end

    def values
      @values ||= Array.wrap(value).sort.uniq
    end

    def empty?
      value.nil? || value == '' || value == []
    end

    # generate a search with this filter removed
    def without
      search = search_instance
      return search if empty?
      new_params = search_instance.params || {}
      new_params.delete(filter_definition.request_param)
      search_instance.class.new_unwrapped(new_params)
    end
  end
end

