module FortyFacets
  # Base class for the classes storing the definition of differently behaving filters
  FilterDefinition = Struct.new(:search, :model_field, :options) do
    def request_param
      model_field
    end
  end
end

