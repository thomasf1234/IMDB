#abstract class
module IMDB
  class Row
    class << self
      def inherited(subclass)
        subclass.init_columns
      end

      def column(name, options={})
        if !has_column?(name)
          @columns << Column.new(name.to_s, options)
        end

        if options[:readonly]
          attr_reader(name)
        else
          attr_accessor(name)
        end
      end

      def columns
        @columns
      end

      def has_column?(name)
        @columns.include?(name.to_s)
      end

      protected
      def init_columns
        @columns = []
      end
    end

    def initialize(params={})
      params.each do |key, value|
        column = key.to_s

        if columns.include?(column)
          instance_variable_set("@#{column}".to_sym, value)
        end
      end
    end

    def columns
      self.class.columns
    end

    def to_hash
      hash = {}

      columns.each do |column|
        hash[column] = send(column)
      end

      hash
    end

    protected
    class Column < String
      def initialize(name, options={})
        super(name)
        @options = options
      end

      def readonly?
        @options[:readonly]
      end
    end
  end
end
