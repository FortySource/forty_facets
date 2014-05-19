module FortyFacets
  class FacetSearch
    attr_reader :filters, :orders


    FieldDefinition = Struct.new(:search, :model_field, :options) do
      def request_param
        model_field
      end
    end

    Filter = Struct.new(:field_definition, :search_instance, :value) do
      def name
        field_definition.options[:name] || field_definition.model_field
      end

      def empty?
        value.nil? || value == '' || value == []
      end

      # generate a search with this filter removed
      def without
        search = search_instance
        return search if empty?
        new_params = search_instance.params
        new_params.delete(field_definition.request_param)
        search_instance.class.new_unwrapped(new_params)
      end
    end

    class RangeField < FieldDefinition
      class RangeFilter < Filter
        def build_scope
          return Proc.new { |base| base } if empty?
          Proc.new {  |base| base.where("#{field_definition.model_field} >= ? AND #{field_definition.model_field} <= ? ", min_value, max_value ) }
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
          @abosultes ||= without.result.select("min(#{field_definition.model_field}) as min, max(#{field_definition.model_field}) as max").first
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

    class TextField < FieldDefinition
      class TextFilter < Filter
        def build_scope
          return Proc.new { |base| base } if empty?
          like_value = expression_value(value)
          Proc.new {  |base| base.where("#{field_definition.model_field} like ?", like_value ) }
        end

        def expression_value(term)
          if field_definition.options[:prefix]
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

    class FacetField < FieldDefinition
      FacetValue = Struct.new(:entity, :count, :selected)

      class FacetFilter < Filter
        def association
          field_definition.search.root_class.reflect_on_association(field_definition.model_field)
        end

        # class objects in this filter
        def klass
          association.klass
        end

        def values
          @values ||= Array.wrap(value).sort.uniq
        end

        def selected
          @selected ||= klass.find(values)
        end

        def build_scope
          return Proc.new { |base| base } if empty?
          Proc.new {  |base| base.where(association.association_foreign_key => values) }
        end

        def facet
          my_column = association.association_foreign_key
          counts = without.result.select("#{my_column} as foreign_id, count(#{my_column}) as occurrences").group(my_column)
          entities_by_id = klass.find(counts.map(&:foreign_id)).group_by(&:id)
          facet = counts.inject([]) do |sum, count|
            facet_entity = entities_by_id[count.foreign_id].first
            is_selected = selected.include?(facet_entity)
            sum << FacetValue.new(facet_entity, count.occurrences, is_selected)
          end

          order_accessor = field_definition.options[:order]
          if order_accessor
            facet.sort_by!{|facet_value| facet_value.entity.send(order_accessor) }
          else
            facet.sort_by!{|facet_value| -facet_value.count }
          end
          facet

        end

        def without
          new_params = search_instance.params || {}
          new_params.delete(field_definition.request_param)
          search_instance.class.new_unwrapped(new_params)
        end

        def remove(value)
          new_params = search_instance.params || {}
          old_values = new_params[field_definition.request_param]
          old_values.delete(value.id.to_s)
          new_params.delete(field_definition.request_param) if old_values.empty?
          search_instance.class.new_unwrapped(new_params)
        end

        def add(entity)
          new_params = search_instance.params || {}
          old_values = new_params[field_definition.request_param] ||= []
          old_values << entity.id.to_s
          search_instance.class.new_unwrapped(new_params)
        end

      end

      def build_filter(search_instance, param_value)
        FacetFilter.new(self, search_instance, param_value)
      end

    end

    class << self
      def model(model_name)
        @model_name = model_name
      end

      def text(model_field, opts = {})
        definitions << TextField.new(self, model_field, opts)
      end

      def range(model_field, opts = {})
        definitions << RangeField.new(self, model_field, opts)
      end

      def facet(model_field, opts = {})
        definitions << FacetField.new(self, model_field, opts)
      end

      OrderDefinition = Struct.new(:title, :clause) do
        def build(search, order_param)
          Order.new(search, self, order_param == title.to_s)
        end

        def request_value
          title
        end
      end

      Order = Struct.new(:search, :definition, :active) do
        def title
          definition.title
        end

        def by
          new_params = search.params || {}
          new_params[:order] = definition.request_value
          search.class.new_unwrapped(new_params)
        end
      end

      def orders(name_and_order_options)
        @order_definitions = name_and_order_options.to_a.inject([]) {|ods, no| ods << OrderDefinition.new(no.first, no.last)}
      end

      def definitions
        @definitions ||= []
      end

      def root_class
        raise 'No model given' unless @model_name
        Kernel.const_get(@model_name)
      end

      def root_scope
        root_class.all
      end

      def request_param(name)
        @request_param_name = name
      end

      def request_param_name
        @request_param_name ||= 'search'
      end

      def order_definitions
        @order_definitions
      end
    end

    def initialize(request_params)
      params = if request_params && request_params[self.class.request_param_name]
                 request_params[self.class.request_param_name]
               else
                 {}
               end
      @filters = self.class.definitions.inject([]) do |filters, definition|
        filters << definition.build_filter(self, params[definition.request_param])
      end

      @orders = self.class.order_definitions.inject([]) do |orders, definition|
        orders << definition.build(self, params[:order])
      end

    end

    def self.new_unwrapped(params)
      self.new(request_param_name => params)
    end

    def filter(filter_name)
      filter = @filters.find { |f| f.field_definition.model_field == filter_name }
      raise "unknown filter #{filter_name}" unless filter
      filter
    end

    def order
      @orders.find(&:active)
    end

    def result
      query = @filters.inject(self.class.root_scope) do |previous, filter|
        filter.build_scope.call(previous)
      end
      query = query.order(order.definition.clause) if order
      query
    end

    def wrapped_params
      { self.class.request_param_name => params }
    end

    def params
      params = @filters.inject({}) do |sum, filter|
        sum[filter.field_definition.request_param] = filter.value.dup unless filter.empty?
        sum
      end
      params[:order] = order.definition.request_value if order
      params
    end

    def path
      unfiltered? ? '?' : '?' + wrapped_params.to_param
    end

    def unfiltered?
      @filters.reject(&:empty?).empty?
    end
  end
end

