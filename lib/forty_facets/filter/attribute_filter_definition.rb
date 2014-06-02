module FortyFacets
  class AttributeFilterDefinition < FilterDefinition
    class AttributeFilter < Filter
      def build_scope
        return Proc.new { |base| base } if empty?
        Proc.new {  |base| base.where(filter_definition.model_field => value) }
      end

      def facet
        my_column = filter_definition.model_field
        counts = without.result.reorder('').select("#{my_column} AS facet_value, count(#{my_column}) as occurrences").group(my_column)
        counts.map{|c| FacetValue.new(c.facet_value, c.occurrences, false)}
      end
    end

    def build_filter(search_instance, value)
      AttributeFilter.new(self, search_instance, value)
    end
  end
end
