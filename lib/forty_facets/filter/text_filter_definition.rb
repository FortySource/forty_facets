module FortyFacets
  class TextFilterDefinition < FilterDefinition
    class TextFilter < Filter
      def build_scope
        return Proc.new { |base| base } if empty?
        like_value = expression_value(value)
        Proc.new {  |base| base.where("#{filter_definition.model_field} like ?", like_value ) }
      end

      def expression_value(term)
        if filter_definition.options[:prefix]
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
