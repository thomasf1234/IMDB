require 'securerandom'

module IMDB
  class RowUuidSequence
    UUID_REGEX = /([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}){1}/

    def self.next
      SecureRandom.uuid
    end
  end
end
