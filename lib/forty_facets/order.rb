module FortyFacets
  # Represents the ordering for a specific search
  Order = Struct.new(:search, :definition, :active) do
    def title
      definition.title
    end

    # Returns a search with the same filter ordered by this criteria
    def by
      new_params = search.params || {}
      new_params[:order] = definition.request_value
      search.class.new_unwrapped(new_params)
    end
  end
end

