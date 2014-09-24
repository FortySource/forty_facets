module FortyFacets
  # Base class for the classes storing the definition of differently behaving filters
  class FilterDefinition

    attr(:search, :path, :options, :joins, :table_name, :column_name,
      :origin_class, :association, :attribute)

    def initialize search, path, options
      @search = search
      @path = [path].flatten
      @options = options

      init_associations
    end

    def request_param
      path.join('-')
    end

    def qualified_column_name
      "#{table_name}.#{column_name}"
    end

    protected

    # Walk the association path and gather required joins, table names etc.
    def init_associations
      current_class = search.root_class
      current_association = nil

      joins = []

      path.each do |current_attribute|
        current_association = current_class.reflect_on_association(current_attribute)

        if current_attribute == path.last
          if current_association
            joins << current_attribute
            @column_name = current_association.foreign_key
          else
            @column_name = current_attribute.to_s
          end
        else
          joins << current_attribute
          current_class = current_association.klass
        end
      end

      @table_name = current_class.table_name
      @origin_class = current_class
      @association = current_association
      @attribute = path.last

      @joins = joins.reverse.drop(1).inject(joins.last) { |a, n| { n => a } }
    end
  end
end

