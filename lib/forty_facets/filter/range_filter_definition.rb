module FortyFacets
  class RangeFilterDefinition < FilterDefinition
    class RangeFilter < Filter
      RANGE_REGEX = /(\d*) - (\d*)/.freeze

      def build_scope
        return Proc.new { |base| base } if empty?

        Proc.new do |base|
          scope = base.joins(definition.joins)
          scope = scope.where("#{definition.qualified_column_name} >= ?", min_value) if min_value.present?
          scope = scope.where("#{definition.qualified_column_name} <= ?", max_value) if max_value.present?
          scope
        end
      end

      def min_value
        min, _max = range_values
        min
      end

      def max_value
        _min, max = range_values
        max
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

      private

      def range_values
        value&.match(RANGE_REGEX)&.captures
      end
    end

    def build_filter(search_instance, value)
      RangeFilter.new(self, search_instance, value)
    end
  end
end
