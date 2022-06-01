# frozen_string_literal: true

module FortyFacets
  class FacetFilterDefinition < FilterDefinition
    class FacetFilter < Filter
      def values
        @values ||= Array.wrap(value).sort.uniq
      end

      protected

      def order_facet!(facet)
        order_accessor = definition.options[:order]
        if order_accessor
          if order_accessor.is_a?(Proc)
            facet.sort_by! { |facet_value| order_accessor.call(facet_value.entity) }
          else
            facet.sort_by! { |facet_value| facet_value.entity.send(order_accessor) }
          end
        else
          facet.sort_by! { |facet_value| -facet_value.count }
        end
        facet
      end
    end

    class AssociationFacetFilter < FacetFilter
      def selected
        @selected ||= definition.association.klass.unscoped.find(Array.wrap(values).reject(&:blank?))
      end

      def remove(entity)
        new_params = search_instance.params || {}
        old_values = new_params[definition.request_param]
        old_values.delete(entity.id.to_s)
        new_params.delete(definition.request_param) if old_values.empty?
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

      def add(entity)
        new_params = search_instance.params || {}

        old_values = new_params[definition.request_param] ||= []
        old_values << entity.id.to_s
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end
    end

    class AttributeFilter < FacetFilter
      def selected
        entity = definition.origin_class
        column = entity.columns_hash[definition.attribute.to_s]
        type = entity.connection.lookup_cast_type_from_column(column)
        values.map { |value| type.serialize(value) }
      end

      def build_scope
        return proc { |base| base } if empty?

        proc do |base|
          base.joins(definition.joins).where(definition.qualified_column_name => value)
        end
      end

      def facet
        my_column = definition.qualified_column_name
        query = "#{my_column} AS facet_value, count(#{my_column}) AS occurrences"
        counts = without.result(skip_ordering: true).distinct.joins(definition.joins).select(query).group(my_column)
        counts.includes_values = []
        facet = counts.map do |c|
          is_selected = selected.include?(c.facet_value)
          FacetValue.new(c.facet_value, c.occurrences, is_selected)
        end

        order_facet!(facet)
      end

      def remove(value)
        new_params = search_instance.params || {}
        old_values = new_params[definition.request_param]
        old_values.delete(value.to_s)
        new_params.delete(definition.request_param) if old_values.empty?
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

      def add(value)
        new_params = search_instance.params || {}
        old_values = new_params[definition.request_param] ||= []
        old_values << value.to_s
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end
    end

    class BelongsToFilter < AssociationFacetFilter
      def build_scope
        return proc { |base| base } if empty?

        proc do |base|
          base.joins(definition.joins).where(definition.qualified_column_name => values)
        end
      end

      def facet
        my_column = definition.qualified_column_name
        query = "#{my_column} AS foreign_id, count(#{my_column}) AS occurrences"
        counts = without.result(skip_ordering: true).distinct.joins(definition.joins).select(query).group(my_column)
        counts.includes_values = []
        entities_by_id = definition.association.klass.unscoped.find(counts.map(&:foreign_id)).group_by(&:id)

        facet = counts.map do |count|
          facet_entity = entities_by_id[count.foreign_id].first
          is_selected = selected.include?(facet_entity)
          FacetValue.new(facet_entity, count.occurrences, is_selected)
        end

        order_facet!(facet)
      end
    end

    class HasManyFilter < AssociationFacetFilter
      def build_scope
        return proc { |base| base } if empty?

        proc do |base|
          base_table = definition.origin_class.table_name

          primary_key_column = "#{base_table}.#{definition.origin_class.primary_key}"

          matches_from_facet = base.joins(definition.joins).where("#{definition.association.klass.table_name}.#{definition.association.klass.primary_key}" => values).select(primary_key_column)

          base.joins(definition.joins).where(primary_key_column => matches_from_facet)
        end
      end

      def facet
        base_table = definition.search.root_class.table_name
        join_name =  [definition.association.name.to_s, base_table.to_s].sort.join('_')
        foreign_id_col = "#{definition.association.name.to_s.singularize}_id"
        my_column = "#{join_name}.#{foreign_id_col}"
        counts = without.result(skip_ordering: true)
                        .distinct
                        .joins(definition.joins)
                        .select("#{my_column} as foreign_id, count(#{my_column}) as occurrences")
                        .group(my_column)
        counts.includes_values = []
        entities_by_id = definition.association.klass.unscoped.find(counts.map(&:foreign_id)).group_by(&:id)

        facet = counts.map do |count|
          facet_entity = entities_by_id[count.foreign_id].first
          is_selected = selected.include?(facet_entity)
          FacetValue.new(facet_entity, count.occurrences, is_selected)
        end

        order_facet!(facet)
      end
    end

    def build_filter(search_instance, param_value)
      if association
        case association.macro
        when :belongs_to
          BelongsToFilter.new(self, search_instance, param_value)
        when :has_many
          HasManyFilter.new(self, search_instance, param_value)
        when :has_and_belongs_to_many
          HasManyFilter.new(self, search_instance, param_value)
        else
          raise "Unsupported association type: #{association.macro}"
        end
      else
        AttributeFilter.new(self, search_instance, param_value)
      end
    end
  end
end
