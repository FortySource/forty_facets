module FortyFacets
  class ScopeFilterDefinition < FilterDefinition
    class ScopeFilter < Filter
      def active?
        value == '1'
      end

      def build_scope
        return Proc.new { |base| base } unless active?
        Proc.new {  |base| base.send(definition.path.first) }
      end

      def remove
        new_params = search_instance.params || {}
        new_params.delete(definition.request_param)
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

      def add
        new_params = search_instance.params || {}
        new_params[definition.request_param] = '1'
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end
    end

    def build_filter(search_instance, value)
      ScopeFilter.new(self, search_instance, value)
    end

  end
end

