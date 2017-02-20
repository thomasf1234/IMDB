#abstract class
require 'securerandom'
require 'set'

module IMDB
  class Table
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
      @deleted_row_uuids = Set.new
      @current_row_index = 0
      @width = columns.count
      @deleted_row_const = @width.times.map { nil }.freeze
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
        new_row = @width.times.map do |i|
          #duplicate frozen obj such that is cannot be altered and does not alter original
          column = columns[i]
          value = row_hash[column]


          if column.unique?
            if @indexes[column].has_key?(value)
              raise IMDB::UniqueConstraintViolation.new(column, value)
            else
              @indexes[column][value] = row_uuid
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
        @indexes['row_uuid'][row_uuid] = @current_row_index
        @current_row_index += 1

        row_uuid
      end
    end

    #threadsafe
    def find(row_uuid)
      lock do
        row_index = @indexes['row_uuid'][row_uuid]

        if row_index.nil?
          raise IMDB::RowNotFound.new(row_uuid: row_uuid)
        elsif @deleted_row_uuids.include?(row_uuid)
          raise IMDB::RowDeleted.new(row_uuid)
        else
          retrieve_row(row_index)
        end
      end
    end

    def all
      lock do
        active_row_uuids = Set.new(@indexes['row_uuid'].keys) - @deleted_row_uuids

        active_row_uuids.map do |row_uuid|
          row_index = @indexes['row_uuid'][row_uuid]

          if row_index.nil?
            raise IMDB::RowNotFound.new(row_uuid: row_uuid)
          else
            retrieve_row(row_index)
          end
        end
      end
    end

    #threadsafe
    def find_by(unique_column, value)
      lock do
        if @indexes.has_key?(unique_column)
          row_uuid = @indexes[unique_column][value]

          if row_uuid.nil?
            raise IMDB::RowNotFound.new({unique_column => value})
          else
            row_index = @indexes['row_uuid'][row_uuid]

            if row_index.nil?
              raise IMDB::RowNotFound.new(row_uuid: row_uuid)
            elsif @deleted_row_uuids.include?(row_uuid)
              raise IMDB::RowDeleted.new(row_uuid)
            else
              retrieve_row(row_index)
            end
          end
        else
          raise IMDB::RowNotFound.new({unique_column => value})
        end
      end
    end


    def update(row_uuid, row_hash)
      lock do
        row_index = @indexes['row_uuid'][row_uuid]

        if row_index.nil?
          raise IMDB::RowNotFound.new('row_uuid' => row_uuid)
        elsif @deleted_row_uuids.include?(row_uuid)
          raise IMDB::RowDeleted.new('row_uuid' => row_uuid)
        else
          #replace the row.
          new_row = @width.times.map do |i|
            column = columns[i]
            new_value = row_hash[column]

            if column.unique?
              if @indexes[column].has_key?(new_value) && @indexes[column][new_value] != row_uuid
                raise IMDB::UniqueConstraintViolation.new(column, new_value)
              else
                @indexes[column][new_value] = row_uuid
              end
            end

            #use original value
            if column.readonly?
              new_value = @data[row_index + i]
            end

            #would rather not do this
            begin
              new_value.dup.freeze
            rescue TypeError
              new_value
            end
          end

          @data[get_range(row_index)] = new_row
        end
      end
    end

    #TODO : delete unique indexes
    def delete(row_uuid)
      lock do
        if @indexes['row_uuid'].has_key?(row_uuid)
          if @deleted_row_uuids.include?(row_uuid)
            raise IMDB::RowDeleted.new(row_uuid)
          else
            row_index = @indexes['row_uuid'][row_uuid]
            row = retrieve_row(row_index)
            @deleted_row_uuids << row_uuid
            unique_columns.each do |column|
              @indexes[column].delete(row[column])
            end
            @data[get_range(row_index)] = @deleted_row_const

          end
        else
          raise IMDB::RowNotFound.new('row_uuid' => row_uuid)
        end
      end
    end

    def delete_all
      lock do
        @deleted_row_uuids.merge(@indexes['row_uuid'].keys)
        unique_columns.each do |column|
          @indexes[column].clear
        end
        @data.fill(nil)
      end
    end

    #TODO : clean out unique indexes
    def vacuum
      lock do
        ordered_row_uuids = @indexes['row_uuid'].sort_by {|row_uuid, row_index| row_index}

        row_index_shift = 0
        ordered_row_uuids.each do |row_uuid, row_index|
          @indexes['row_uuid'][row_uuid] += row_index_shift

          if @deleted_row_uuids.include?(row_uuid)
            new_row_index = row_index + row_index_shift
            @data[get_range(new_row_index)] = []
            @indexes['row_uuid'].delete(row_uuid)

            row_index_shift -= 1
          end
        end
        @current_row_index += row_index_shift

        @deleted_row_uuids.clear
      end
    end

    def columns
      self.class.columns
    end

    def unique_columns
      columns.select(&:unique?)
    end

    def empty?
      lock do
        @data.compact.empty?
      end
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

    #not threadsafe
    def retrieve_row(row_index)
      raw_row = @data[get_range(row_index)]

      row = {}

      @width.times do |i|
        #checking if immediate value
        value = begin
          raw_row[i].dup
        rescue TypeError
          raw_row[i]
        end

        row[columns[i]] = value
      end

      row
    end

    def get_range(row_index)
      start_data_index = row_index * @width
      end_data_index = start_data_index + @width - 1
      (start_data_index..end_data_index)
    end
  end
end
