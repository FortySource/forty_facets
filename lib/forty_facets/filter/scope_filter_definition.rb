module FortyFacets
  class ScopeFilterDefinition < FilterDefinition
    class ScopeFilter < Filter
      def active?
        definition.options[:pass_value] ? value.present? : value == '1'
      end

      def selected 
        [value]
      end

      def build_scope
        return proc { |base| base } unless active?

        proc { |base|
          if definition.options[:pass_value]
            base.send(definition.path.first, value)  
          else
            base.send(definition.path.first) 
          end
        }
      end

      # added value to standardize the API even though it's not used
      def remove(value = nil)
        new_params = search_instance.params || {}
        new_params.delete(definition.request_param)
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end

      def add(value = '1')
        new_params = search_instance.params || {}
        new_params[definition.request_param] = value
        search_instance.class.new_unwrapped(new_params, search_instance.root)
      end
    end

    def build_filter(search_instance, value)
      ScopeFilter.new(self, search_instance, value)
    end
  end
end
