module FortyFacets
  class HasManyFilterDefinition < FilterDefinition
    class HasManyFilter < FacetFilter
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
        Proc.new do |base|
          base_table = filter_definition.search.root_class.table_name
          join_name =  [association.name.to_s, base_table.to_s].sort.join('_')
          foreign_id_col = association.name.to_s.singularize + '_id'
          # this will actually generate a subquery
          base.where(id: base.joins(association.options[:through])
              .where(join_name + '.' + foreign_id_col => values)
              .group(base_table + '.id').select(base_table + '.id'))
        end
      end

      def facet
        base_table = filter_definition.search.root_class.table_name
        join_name =  [association.name.to_s, base_table.to_s].sort.join('_')
        foreign_id_col = association.name.to_s.singularize + '_id'
        my_column = join_name + '.' + foreign_id_col
        counts = without.result
                  .reorder('')
                  .joins(association.options[:through])
                  .select("#{my_column} as foreign_id, count(#{my_column}) as occurrences")
                  .group(my_column)
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
      HasManyFilter.new(self, search_instance, param_value)
    end

  end
end

