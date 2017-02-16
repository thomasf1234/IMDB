require 'singleton'
require 'lock'

module IMDB
  class DB
    include Singleton
    include Lock

    def init
      @db = {} if @db.nil?
    end

    def close

    end

    def insert(record)

    end

    def find(record_klass, uuid)

    end

    def update(record)

    end

    def delete(record)

    end

    private
    class Table < Array
      def contains_row_uuid?(uuid)
        contains_row_uuid = false

        each do |row|
          if row[:row_uuid] == uuid
            contains_row_uuid = true
            break
          end
        end

        contains_row_uuid
      end
    end
  end
end
