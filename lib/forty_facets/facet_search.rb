module FortyFacets
  # Inherit this class to create a custom search for your model
  #
  #   class MovieSearch < FortyFacets::FacetSearch
  #     model 'Movie'
  #
  #     text :title
  #     scope :someScope, name: 'Only very special'
  #     range :price
  #     facet :genre, name: 'Genre'
  #     facet :year, name: 'Releaseyear', order: :year
  #     facet :studio, name: 'Studio', order: :name
  #
  #     orders 'Title' => :title,
  #            'price, cheap first' => "price asc",
  #            'price, expensive first' => {price: :desc, title: :desc},
  #            'Title, reverse' => {order: "title desc", default: true}
  #     custom :for_manual_handling
  #
  #   end
  class FacetSearch
    attr_reader :filters, :orders

    class << self
      def model(model)
        if model.is_a? Class
          @root_class = model
        else
          @root_class = Kernel.const_get(model)
        end
      end

      def text(path, opts = {})
        definitions << TextFilterDefinition.new(self, path, opts)
      end

      def custom(path, opts = {})
        definitions << CustomFilterDefinition.new(self, path, opts)
      end

      def scope(path, opts = {})
        definitions << ScopeFilterDefinition.new(self, path, opts)
      end

      def range(path, opts = {})
        definitions << RangeFilterDefinition.new(self, path, opts)
      end

      def facet(path, opts = {})
        definitions << FacetFilterDefinition.new(self, path, opts)
      end

      def sql_facet(queries, opts = {})
        definitions << SqlFacetFilterDefinition.new(self, queries, opts)
      end

      def orders(name_and_order_options)
        @order_definitions = name_and_order_options.to_a.inject([]) {|ods, no| ods << OrderDefinition.new(no.first, no.last)}
      end

      def definitions
        @definitions ||= []
      end

      def root_class
        @root_class || raise('No model class given')
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

    def initialize(request_params = {}, root = nil)
      params = request_to_search_params(request_params)
      @filters = self.class.definitions.inject([]) do |filters, definition|
        filters << definition.build_filter(self, params[definition.request_param])
      end

      @orders = self.class.order_definitions.inject([]) do |orders, definition|
        orders << definition.build(self, params[:order])
      end

      unless @orders.find(&:active)
        default_order = @orders.find {|o| o.definition.default}
        default_order.active = true if default_order
      end

      @root = root
    end

    def self.new_unwrapped(params, root)
      self.new({request_param_name => params}, root)
    end

    def filter(filter_name)
      filter = @filters.find { |f| f.definition.path == [filter_name].flatten }
      raise "Unknown filter #{filter_name}" unless filter
      filter
    end

    def order
      @orders.find(&:active)
    end

    def result(skip_ordering: false)
      query = @filters.reject(&:empty?).inject(root) do |previous, filter|
        filter.build_scope.call(previous)
      end

      if order && !skip_ordering
        query = order.apply(query)
      else
        query = query.distinct
      end
      query
    end

    def wrapped_params
      return {} if params.empty?
      { self.class.request_param_name => params }
    end

    def params
      params = @filters.inject({}) do |sum, filter|
        sum[filter.definition.request_param] = filter.value.dup unless filter.empty?
        sum
      end
      params[:order] = order.definition.request_value if order
      params
    end

    def path
      return nil if wrapped_params.empty?
      '?' + wrapped_params.to_param
    end

    def unfiltered?
      @filters.reject(&:empty?).empty?
    end

    def root
      @root || self.class.root_scope
    end

    def change_root new_root
      @root = new_root
    end

    private

    def request_to_search_params(request_params)
      if request_params && request_params[self.class.request_param_name]
        should_be_hash = request_params[self.class.request_param_name]
        if should_be_hash.respond_to?(:permit!)
          should_be_hash = should_be_hash.permit!.to_h
        end
        if should_be_hash.is_a? Hash
          should_be_hash
        else
          {}
        end
      else
        {}
      end
    end

  end
end

