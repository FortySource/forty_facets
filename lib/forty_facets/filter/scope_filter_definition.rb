module FortyFacets
  class ScopeFilterDefinition < FilterDefinition
    class ScopeFilter < Filter
      def active?
        value.present?
      end

      def build_scope
        return Proc.new { |base| base } unless active?
        Proc.new {  |base|
          arity = base.method(definition.path.first.to_sym).arity
          base.send(definition.path.first, value) 
          # if arity == 0
          #   base.send(definition.path.first) 
          # else 
          #   base.send(definition.path.first, value) 
          # end
        }
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

    def build_filter(search_instance, value)
      ScopeFilter.new(self, search_instance, value)
    end

  end
end

