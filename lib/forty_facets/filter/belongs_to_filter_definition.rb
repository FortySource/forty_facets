module FortyFacets
  class BelongsToFilterDefinition < FilterDefinition
    class BelongsToFilter < FacetFilter
      def association
        filter_definition.search.root_class.reflect_on_association(filter_definition.model_field)
      end

      # class objects in this filter
      def klass
        association.klass
      end

      def selected
        @selected ||= klass.find(values)
      end

      def build_scope
        return Proc.new { |base| base } if empty?
        Proc.new {  |base| base.where(association.association_foreign_key => values) }
      end

      def facet
        my_column = "#{filter_definition.search.root_class.table_name}.#{association.association_foreign_key}"
        counts = without.result.reorder('').select("#{my_column} as foreign_id, count(#{my_column}) as occurrences").group(my_column)
        entities_by_id = klass.find(counts.map(&:foreign_id)).group_by(&:id)

        facet = counts.map do |count|
          facet_entity = entities_by_id[count.foreign_id].first
          is_selected = selected.include?(facet_entity)
          FacetValue.new(facet_entity, count.occurrences, is_selected)
        end

        order_facet!(facet)
      end

      def remove(entity)
        new_params = search_instance.params || {}
        old_values = new_params[filter_definition.request_param]
        old_values.delete(entity.id.to_s)
        new_params.delete(filter_definition.request_param) if old_values.empty?
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

      def add(entity)
        new_params = search_instance.params || {}
        old_values = new_params[filter_definition.request_param] ||= []
        old_values << entity.id.to_s
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

    end

    def build_filter(search_instance, param_value)
      BelongsToFilter.new(self, search_instance, param_value)
    end

  end
end
