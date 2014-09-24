module FortyFacets
  class RangeFilterDefinition < FilterDefinition
    class RangeFilter < Filter
      def build_scope
        return Proc.new { |base| base } if empty?

        Proc.new do |base|
          base.joins(definition.joins)
            .where("#{definition.qualified_column_name} >= ? AND #{definition.qualified_column_name} <= ? ", min_value, max_value ) 
        end
      end

      def min_value
        return nil if empty?
        value.split(' - ').first
      end

      def max_value
        return nil if empty?
        value.split(' - ').last
      end

      def absolute_interval
        @abosultes ||= without.result.reorder('').select("min(#{definition.qualified_column_name}) AS min, max(#{definition.qualified_column_name}) as max").first
      end

      def absolute_min
        absolute_interval.min
      end

      def absolute_max
        absolute_interval.max
      end

    end

    def build_filter(search_instance, value)
      RangeFilter.new(self, search_instance, value)
    end
  end
end
