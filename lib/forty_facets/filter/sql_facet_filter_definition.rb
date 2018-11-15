module FortyFacets
  class SqlFacetFilterDefinition < FilterDefinition
    attr_reader(:queries)

    def initialize(search, queries, opts)
      @search = search
      @queries = queries
      @path = Array(opts[:path]) if opts[:path].present?
      @joins = Array(opts[:joins]) if opts[:joins].present?
      @path ||= @queries.keys
      @options = opts
    end

    def request_param
      path.join("-")
    end

    def build_filter(search_instance, param_value)
      ScopeFacetFilter.new(self, search_instance, param_value)
    end

    class ScopeFacetFilter < Filter
      def values
        @values ||= Array.wrap(value).sort.uniq
      end

      def build_scope
        return Proc.new { |base| base } if empty?

        Proc.new do |base|
          # intersection of values and definition queries
          base.where(selected_queries.values.map do |query|
            "(#{query})"
          end.join(" OR "))
        end
      end

      def selected
        values
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

      def facet
        query = definition.queries.map do |key, sql_query|
          "(#{sql_query}) as #{key}"
        end.join(", ")
        query += ", count(*) as occurrences"
        
        counts = without.result.reorder("")
          .select(query)
          .group(definition.queries.keys)
        counts = counts.joins(definition.joins) if definition.joins
        counts.includes_values = []

        result = {}

        counts.map do |count|
          definition.queries.each do |key, _|
            result[key] ||= 0
            if [1, "1", true].include?(count[key])
              result[key] += count.occurrences
            end
          end
        end

        result.map do |key, count|
          key = key.to_sym
          is_selected = selected_queries.keys.include?(key)
          FacetValue.new(key, count, is_selected)
        end
      end

      private

      def selected_queries
        @selected_queries ||= definition.queries.select do |key, _|
          values.map(&:to_sym).include? key
        end
      end
    end
  end
end
