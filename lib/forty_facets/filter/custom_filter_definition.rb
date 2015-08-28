module FortyFacets
  class CustomFilterDefinition < FilterDefinition
    class CustomFilter < Filter
      def build_scope
        return Proc.new { |base| base } # the custom filter doesn alter the query at all
                                        # but you can use it's state to modify the base_scope
                                        # in your controller
      end

      def set(new_value)
        new_params = search_instance.params || {}

        new_params[definition.request_param] = new_value
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

    end

    def build_filter(search_instance, value)
      CustomFilter.new(self, search_instance, value)
    end

  end
end


