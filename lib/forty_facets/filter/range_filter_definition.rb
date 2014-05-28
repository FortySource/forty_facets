module FortyFacets
  class RangeFilterDefintion < FilterDefinition
    class RangeFilter < Filter
      def build_scope
        return Proc.new { |base| base } if empty?
        Proc.new {  |base| base.where("#{filter_definition.model_field} >= ? AND #{filter_definition.model_field} <= ? ", min_value, max_value ) }
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
        @abosultes ||= without.result.reorder('').select("min(#{filter_definition.model_field}) as min, max(#{filter_definition.model_field}) as max").first
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
