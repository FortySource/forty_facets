module FortyFacets
  # Stores the parameters of a order criteria for a search.
  OrderDefinition = Struct.new(:title, :clause) do
    def build(search, order_param)
      Order.new(search, self, order_param == title.to_s)
    end

    # Returns the value that is used in the request parameter to indicate that
    # the search result is ordered by this criteria.
    def request_value
      title
    end
  end
end

