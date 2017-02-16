#abstract class
module IMDB
  class Table
    include IMDB::Lock

    attr_reader :name

    def initialize(name)
      @name = name
      @rows = {}
      @deleted_rows = {}
    end

    def insert(row)
      lock do
        row_uuid = next_row_uuid

        while (@rows.has_key?(row_uuid) || @deleted_rows.has_key?(row_uuid))
          row_uuid = next_row_uuid
        end

        @rows[row_uuid] = row.to_hash
        row_uuid
      end
    end

    def find(row_uuid)
      lock do
        row = @rows[row_uuid]

        if row.nil?
          raise IMDB::RowNotFound.new(row_uuid: row_uuid)
        else
          row
        end
      end
    end

    def update(row_uuid, row)
      lock do
        @rows[row_uuid] = row.to_hash
      end
    end

    def delete(row_uuid)
      lock do
        @deleted_rows[row_uuid] = @rows.delete(row_uuid)
      end
    end

    def empty?
      lock do
        @rows.empty?
      end
    end

    private
    def next_row_uuid
      IMDB::RowUuidSequence.next
    end
  end
end
