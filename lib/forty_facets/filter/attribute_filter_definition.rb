module FortyFacets
  class AttributeFilterDefinition < FilterDefinition
    class AttributeFilter < FacetFilter
      def selected
        entity = search_instance.class.root_class
        column = entity.columns_hash[filter_definition.model_field.to_s]
        values.map{|v| column.type_cast(v)}
      end

      def build_scope
        return Proc.new { |base| base } if empty?
        Proc.new {  |base| base.where(filter_definition.model_field => value) }
      end

      def facet
        my_column = filter_definition.model_field
        counts = without.result.reorder('').select("#{my_column} AS facet_value, count(#{my_column}) as occurrences").group(my_column)
        facet = counts.map do |c|
          is_selected = selected.include?(c.facet_value)
          FacetValue.new(c.facet_value, c.occurrences, is_selected)
        end

        order_facet!(facet)
      end

      def remove(value)
        new_params = search_instance.params || {}
        old_values = new_params[filter_definition.request_param]
        old_values.delete(value.to_s)
        new_params.delete(filter_definition.request_param) if old_values.empty?
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

      def add(value)
        new_params = search_instance.params || {}
        old_values = new_params[filter_definition.request_param] ||= []
        old_values << value.to_s
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end
    end

    def build_filter(search_instance, value)
      AttributeFilter.new(self, search_instance, value)
    end
  end
end
