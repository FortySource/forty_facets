module FortyFacets
  class TextFilterDefinition < FilterDefinition
    class TextFilter < Filter
      def build_scope
        return Proc.new { |base| base } if empty?
        like_value = expression_value(value)
        operator = definition.options[:ignore_case] ? 'ILIKE' : 'LIKE'
        Proc.new {  |base| base.joins(definition.joins).where("#{definition.qualified_column_name} #{operator} ?", like_value ) }
      end

      def expression_value(term)
        if definition.options[:prefix]
         "#{term}%"
        else
         "%#{term}%"
        end
      end
    end

    def build_filter(search_instance, value)
      TextFilter.new(self, search_instance, value)
    end
  end
end
