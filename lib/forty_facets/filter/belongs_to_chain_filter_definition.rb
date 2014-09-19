module FortyFacets
  class BelongsToChainFilterDefinition < FilterDefinition
    class BelongsToChainFilter < FacetFilter
      def association
        current_association = nil
        current_class = filter_definition.search.root_class

        filter_definition.model_field.each do |field|
          current_association = current_class.reflect_on_association(field)
          current_class = current_association.klass
        end

        current_association
      end

      # class objects in this filter
      def klass
        association.klass
      end

      def selected
        @selected ||= klass.find(values)
      end

      def joins
        fields = filter_definition.model_field
        fields.reverse.drop(1).inject(fields.last) { |a, n| { n => a } }
      end

      def build_scope
        return Proc.new { |base| base } if empty?

        Proc.new do |base|
          condition = {association.klass.table_name => {id: values}}
          base.joins(joins).where(condition)
        end
      end

      def facet
        current_association = nil
        current_class = filter_definition.search.root_class
        filter_definition.model_field.reverse.drop(1).reverse.each do |field|
          current_association = current_class.reflect_on_association(field)
          current_class = current_association.klass
        end

        my_column = "#{current_class.table_name}.#{association.association_foreign_key}"
        counts = without.result.reorder('').joins(joins).select("#{my_column} AS foreign_id, count(#{my_column}) AS occurrences").group(my_column)
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
      BelongsToChainFilter.new(self, search_instance, param_value)
    end

    def request_param
      model_field.join('-')
    end

  end
end
