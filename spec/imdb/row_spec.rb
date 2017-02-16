require 'spec_helper'

module RowSpec
  class TestRow < IMDB::Row
    column :field1
    column :field2
    column :field3, {readonly: true}
  end

  describe IMDB::Row do
    describe ".columns" do
      it 'adds all of the columns declared in the class and the row_uuid that is common amongst all rows' do
        expect(TestRow.columns).to match_array(['field1', 'field2', 'field3'])
        expect(TestRow.columns.select(&:readonly?)).to match_array(['field3'])
      end
    end

    describe "#initialize" do
      context 'no args passed' do
        it 'does not assign any fields' do
          test_row = TestRow.new

          expect(test_row.field1).to eq(nil)
          expect(test_row.field2).to eq(nil)
          expect(test_row.field3).to eq(nil)
        end
      end

      context 'row_uuid passed' do
        it 'does not assign any fields' do
          test_row = TestRow.new(row_uuid: 'd4b97ec8-623c-4707-b21a-5ace0dde6c9f')

          expect(test_row.field1).to eq(nil)
          expect(test_row.field2).to eq(nil)
          expect(test_row.field3).to eq(nil)
        end
      end

      context 'args passed assoicated with columns' do
        it "assigns the values to the attributes, readonly enforces attr_reader only" do
          test_row = TestRow.new({field1: 'foo', field2: 'bar', field3: 'another'})

          expect(test_row.field1).to eq('foo')
          expect(test_row.field2).to eq('bar')
          expect(test_row.field3).to eq('another')

          expect { test_row.field1 = 'foo foo' }.to_not raise_error
          expect { test_row.field2 = 'bar bar' }.to_not raise_error
          expect { test_row.field3 = 'another another' }.to raise_error
        end
      end

      context 'args passed not assoicated with columns' do
        it 'only assigns the attributes associated with columns' do
          test_row = TestRow.new({field4: 'foo', field2: 'bar', field3: 'another'})

          expect(test_row.field1).to eq(nil)
          expect(test_row.field2).to eq('bar')
          expect(test_row.field3).to eq('another')
          expect(test_row.respond_to?(:field4)).to eq(false)
        end
      end
    end

    describe '#to_hash' do
      it 'creates a has representation of the row obj' do
        test_row = TestRow.new({field1: 'foo', field2: 'bar', field3: 'another'})
        expect(test_row.to_hash).to eq({'field1' => 'foo', 'field2' => 'bar', 'field3' => 'another'})
      end
    end
  end
end

