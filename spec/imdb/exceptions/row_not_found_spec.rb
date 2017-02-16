require 'spec_helper'

module RowNotFoundSpec
  describe IMDB::RowNotFound do
    describe "#" do
      it 'contains the search parameters passed' do
        begin
          raise IMDB::RowNotFound.new({'row_uuid' => "5bc8e798-1600-4294-a403-4d319e338afd", 'name' => 'test'})
        rescue IMDB::Exception => e
          expect(e.message).to eq("Could not find row with search params passed")
          expect(e.search_params).to eq({'row_uuid' => "5bc8e798-1600-4294-a403-4d319e338afd", 'name' => 'test'})
        end
      end
    end
  end
end

