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
      search.class.new_unwrapped(new_params, search.root)
    end

    def apply(query)
      if [Symbol, String, Hash].include? definition.clause.class
        query.order(definition.clause)
      elsif definition.clause.is_a? Array # [:person, :first_name]
        # new and unelegant handling of ordering by columns from joined tables
        root_table = search.class.root_class.table_name
        primary_key = search.class.root_class.primary_key
        just_ids = query.select("#{root_table}.#{primary_key}")
        path_to_order_property = definition.clause
        order_class = path_to_order_property
                      .take(path_to_order_property.length - 1)
                      .inject(search.class.root_class) do |prev_class, assoc_name|
                        prev_class.reflect_on_association(assoc_name).klass
                      end
        joins = path_to_order_property
                  .reverse
                  .drop(1)
                  .inject(nil) do |sum, elem|
                    if sum
                      {elem => sum}
                    else
                      elem
                    end
                  end
        search.root
          .joins(joins)
          .where(search.class.root_class.primary_key => just_ids)
          .order("#{order_class.table_name}.#{path_to_order_property.last}")
      end

    end
  end
end

