#abstract class
require 'securerandom'

module IMDB
  class Table2
    include IMDB::Lock

    attr_reader :name

    class << self
      def define_columns
        @columns = []
        yield
        @columns.freeze
      end

      def column(name, data_type, options={})
        name = name.to_s

        if !has_column?(name)
          @columns.push(Column.new(name, data_type, options))
        end
      end

      def columns
        @columns
      end

      def has_column?(name)
        @columns.include?(name.to_s)
      end

      def get_column(name)
        if has_column?(name)
          @columns.detect { |column| column == name.to_s }
        else
          nil
        end
      end
    end

    def initialize(name)
      @name = name
      @indexes = {'row_uuid' => {}}
      columns.each do |column|
        if column.unique?
          @indexes[column] = {}
        end
      end
      @data = []
      @current_index = 0
    end

    def insert(row_hash)
      #TODO : must first validate row_hash

      lock do
        #get unique uuid
        row_uuid = generate_uuid
        while @indexes['row_uuid'].has_key?(row_uuid)
          row_uuid = generate_uuid
        end

        #add the row.
        new_row = columns.count.times.map do |i|
          #duplicate frozen obj such that is cannot be altered and does not alter original
          column = columns[i]
          value = row_hash[column]


          if column.unique?
            if @indexes[column].has_key?(value)
              raise IMDB::UniqueConstraintViolation.new(column, value)
            else
              @indexes[column][value] = @current_index
            end
          end

          #would rather not do this
          begin
            value.dup.freeze
          rescue TypeError
            value
          end
        end
        @data.push(*new_row)

        #update the indexes
        @indexes['row_uuid'][row_uuid] = @current_index
        @current_index += 1

        row_uuid
      end
    end

    def find(row_uuid)
      lock do
        table_index = @indexes['row_uuid'][row_uuid]

        if table_index.nil?
          raise IMDB::RowNotFound.new(row_uuid: row_uuid)
        else
          width = columns.count

          start_index = table_index * width
          end_index = start_index + width - 1
          row = @data[start_index..end_index]
          row
        end
      end
    end

    def columns
      self.class.columns
    end

    protected
    #unmodifiable post initialization
    class Column < String
      attr_reader :data_type_klass

      def initialize(name, data_type_klass, options={})
        super(name.dup)
        @data_type_klass = data_type_klass
        @options = options.dup.freeze
        freeze
      end

      def readonly?
        @options[:readonly] == true
      end

      def unique?
        @options[:unique] == true
      end
    end

    private
    def generate_uuid
      SecureRandom.uuid
    end
  end
end

#40MB 1,000,000 rows
#100MB indexes
#20 microseconds for a find(row_uuid)
