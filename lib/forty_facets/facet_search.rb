module FortyFacets
  # Inherit this class to create a custom search for your model
  #
  #   class MovieSearch < FortyFacets::FacetSearch
  #     model 'Movie'
  #
  #     text :title
  #     range :price
  #     facet :genre, name: 'Genre'
  #     facet :year, name: 'Releaseyear', order: :year
  #     facet :studio, name: 'Studio', order: :name
  #
  #     orders 'Title' => :title,
  #            'price, cheap first' => "price asc",
  #            'price, expensive first' => {price: :desc, title: :desc}
  #
  #   end
  class FacetSearch
    attr_reader :filters, :orders

    class << self
      def model(model_name)
        @model_name = model_name
      end

      def text(model_field, opts = {})
        definitions << TextFilterDefinition.new(self, model_field, opts)
      end

      def range(model_field, opts = {})
        definitions << RangeFilterDefinition.new(self, model_field, opts)
      end

      def facet(model_field, opts = {})
        if self.root_scope.reflect_on_association(model_field)
          definitions << BelongsToFilterDefinition.new(self, model_field, opts)
        else
          definitions << AttributeFilterDefinition.new(self, model_field, opts)
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
        @order_definitions ||= []
      end
    end

    def initialize(request_params = {})
      params = request_to_search_params(request_params)
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
      filter = @filters.find { |f| f.filter_definition.model_field == filter_name }
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
        sum[filter.filter_definition.request_param] = filter.value.dup unless filter.empty?
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

    private

    def request_to_search_params(request_params)
      if request_params && request_params[self.class.request_param_name]
        request_params[self.class.request_param_name]
      else
        {}
      end
    end

  end
end

