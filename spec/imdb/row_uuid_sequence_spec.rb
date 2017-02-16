require 'spec_helper'

module RowUuidSequenceSpec
  describe IMDB::RowUuidSequence do
    describe "#next" do
      it 'generates a uuid' do
        next_val = IMDB::RowUuidSequence.next
        expect(next_val).to match(IMDB::RowUuidSequence::UUID_REGEX)

        next_val = IMDB::RowUuidSequence.next
        expect(next_val).to match(IMDB::RowUuidSequence::UUID_REGEX)
      end
    end
  end
end

