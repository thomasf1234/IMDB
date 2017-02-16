require 'spec_helper'

module TableSpec
  class TestRow < IMDB::Row
    column :field1
    column :field2
  end

  describe IMDB::Table do
    describe "#initialize" do
      it 'is empty' do
        table = IMDB::Table.new("my_table")

        expect(table.name).to eq("my_table")
        expect(table.empty?).to eq(true)
      end
    end

    describe "#insert" do
      context 'empty' do
        let(:table) { IMDB::Table.new("my_table") }
        let(:test_row) { TestRow.new(field1: 'myfield', field2: 'myotherfield') }

        it 'adds a hash representation of the row and returns the row_uuid' do
          row_uuid = table.insert(test_row)
          expect(row_uuid).to match(IMDB::RowUuidSequence::UUID_REGEX)
          expect(table.instance_variable_get(:@rows)).to eq({row_uuid => {'field1' => 'myfield', 'field2' => 'myotherfield'}})
          expect(table.instance_variable_get(:@deleted_rows)).to eq({})
        end
      end

      context 'populated' do
        let(:table) { IMDB::Table.new("my_table") }
        let(:test_row1) { TestRow.new(field1: 'myfield', field2: 'myotherfield') }
        let(:test_row2) { TestRow.new(field1: 'myfield1', field2: 'myotherfield2') }

        context 'uuid not already used' do
          it 'adds a hash representation of the row and returns the row_uuid' do
            row_uuid1 = table.insert(test_row1)
            row_uuid2 = table.insert(test_row2)

            expect(row_uuid1).to match(IMDB::RowUuidSequence::UUID_REGEX)
            expect(row_uuid2).to match(IMDB::RowUuidSequence::UUID_REGEX)
            expect(row_uuid1).to_not eq(row_uuid2)
            expect(table.instance_variable_get(:@rows)).to eq({row_uuid1 => {'field1' => 'myfield', 'field2' => 'myotherfield'},
                                                               row_uuid2 => {'field1' => 'myfield1', 'field2' => 'myotherfield2'}})
            expect(table.instance_variable_get(:@deleted_rows)).to eq({})
          end
        end

        context 'uuid already used' do
          context 'currently used in main table' do
            let(:expected_row_uuid) { "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b" }

            it 'keeps attempting next row_uuid until a valid one is generated' do
              already_used_row_uuid = table.insert(test_row1)
              allow(table).to receive(:next_row_uuid).and_return(already_used_row_uuid, already_used_row_uuid, expected_row_uuid)

              row_uuid = table.insert(test_row2)

              expect(row_uuid).to eq(expected_row_uuid)
              expect(table.instance_variable_get(:@rows)).to eq({already_used_row_uuid => {'field1' => 'myfield', 'field2' => 'myotherfield'},
                                                                  expected_row_uuid => {'field1' => 'myfield1', 'field2' => 'myotherfield2'}})
              expect(table.instance_variable_get(:@deleted_rows)).to eq({})
            end
          end

          #It is very unlikely for duplicate but I cater for it: "Thus, for there to be a one in a billion chance of duplication, 103 trillion version 4 UUIDs must be generated."
          context 'only present in the delete_rows table' do
            let(:already_used_row_uuid) { "e5a1020d-bb4a-4d9d-81e5-f6cf370aa102" }
            let(:expected_row_uuid) { "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b" }

            it 'keeps attempting next row_uuid until a valid one is generated' do
              table.instance_variable_set(:@deleted_rows, {already_used_row_uuid => {'field1' => 'myfield', 'field2' => 'myotherfield'}})

              allow(table).to receive(:next_row_uuid).and_return(already_used_row_uuid, already_used_row_uuid, expected_row_uuid)

              row_uuid = table.insert(test_row2)

              expect(row_uuid).to eq(expected_row_uuid)
              expect(table.instance_variable_get(:@rows)).to eq({expected_row_uuid => {'field1' => 'myfield1', 'field2' => 'myotherfield2'}})
              expect(table.instance_variable_get(:@deleted_rows)).to eq({already_used_row_uuid => {'field1' => 'myfield', 'field2' => 'myotherfield'}})
            end
          end
        end
      end
    end

    describe '#find' do
      let(:table) { IMDB::Table.new("my_table") }
      let(:test_row1) { TestRow.new(field1: 'myfield1', field2: 'myotherfield1') }
      let(:test_row2) { TestRow.new(field1: 'myfield2', field2: 'myotherfield2') }

      context 'row doesnt exist' do
        it 'throws RowNotFound exception' do
          begin
            table.find("671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
            fail("Should have thrown IMDB::RowNotFound")
          rescue IMDB::RowNotFound => e
            expect(e.search_params).to eq(row_uuid: "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
          end
        end
      end

      context 'row exists' do
        it 'returns the raw hash' do
          row_uuid1 = table.insert(test_row1)
          row_uuid2 = table.insert(test_row2)
          expect(table.find(row_uuid1)).to eq({'field1' => 'myfield1', 'field2' => 'myotherfield1'})
          expect(table.find(row_uuid2)).to eq({'field1' => 'myfield2', 'field2' => 'myotherfield2'})
        end
      end
    end

    describe '#update' do
      let(:table) { IMDB::Table.new("my_table") }
      let(:test_row1) { TestRow.new(field1: 'myfield1', field2: 'myotherfield1') }
      let(:test_row2) { TestRow.new(field1: 'myfield2', field2: 'myotherfield2') }

      it 'throws RowNotFound exception' do
        begin
          table.update("671abb20-ced8-4f1d-87d0-cb4ad16e3a3b", )
          fail("Should have thrown IMDB::RowNotFound")
        rescue IMDB::RowNotFound => e
          expect(e.search_params).to eq(row_uuid: "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
        end
      end

      context 'row exists' do
        it 'returns the raw hash' do
          row_uuid1 = table.insert(test_row1)
          row_uuid2 = table.insert(test_row2)
          expect(table.find(row_uuid1)).to eq({'field1' => 'myfield1', 'field2' => 'myotherfield1'})
          expect(table.find(row_uuid2)).to eq({'field1' => 'myfield2', 'field2' => 'myotherfield2'})
        end
      end
    end
  end
end

#
# def time_it
#   t0 = Time.now
#   result = yield
#   t1 = Time.now
#   duration = t1 - t0
#   [result, duration]
# end
#
# require 'securerandom'
# rows_with_columns = {}
# rows_without_columns = {}
# columns = ['column1', 'column2']
#
# 10000000.times do |i|
#   row_uuid = SecureRandom.uuid
#   rows_with_columns[row_uuid] = {'column1' => 'b', 'column2' => i}
#   rows_without_columns[row_uuid] = ['b', i]
#   nil
# end
#
# result = nil
# time_it { rows.select {|k,v| v['port'] == 500000} }
#
#
#         #column1, column2, column1, column2
# table = ['b', 1, 'b', 2, 'b', 3]
# row_uuid_index = {"671abb20-ced8-4f1d-87d0-cb4ad16e3a3b" => 0, "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b" => 1}
#
# table_index = row_uuid_index["671abb20-ced8-4f1d-87d0-cb4ad16e3a3b"]
# table[table_index..table_index+(columns.count-1)]
#
#
# require 'securerandom'
# table = []
# row_uuid_index = {}
# 1000000.times do |i|
#   row_uuid = SecureRandom.uuid
#   table << 'something'
#   table << 'name'
#   table << i
#   row_uuid_index[row_uuid] = i
#   nil
# end
#
# row_uuid = '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b'
# columns_count = 3
# def time_fetch(row_uuid)
#   time_it do
#     table_index = row_uuid_index[row_uuid]
#     start_index = table_index*columns_count
#     end_index = table_index*columns_count + columns_count - 1
#     table[start_index..end_index]
#   end
# end
#
#
#
#

def time_it
  t0 = Time.now
  result = yield
  t1 = Time.now
  duration = t1 - t0
  [result, duration]
end
#
# require 'securerandom'
# a = 1000000.times.map { SecureRandom.uuid } ; nil
#
# row = 100000.times.map { SecureRandom.uuid } ; nil
# row = ['a', 'b', 'c', 'd', 'e', 'f']
#
#
# time_it do
#   new_row = row.map {|col| col.dup.freeze }
#   a[index..index+100000-1] = new_row
#   nil
# end
#
#
# column_count = 100000
#
# def insert(row)
#   row_uuid = SecureRandom.uuid
#
#   (0..(column_count-1)).each do |i|
#     table << row[i].dup.freeze
#   end
#   row_uuid_index[row_uuid] = i
# end
#
# row_uuid = '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b'
# columns_count = 3
# def find(row_uuid)
#   table_index = row_uuid_index[row_uuid]
#   start_index = table_index*columns_count
#   end_index = table_index*columns_count + columns_count - 1
#   table[start_index..end_index]
# end
#
# def update(row)
#   (0..(column_count-1)).each do |i|
#     a[index+i] = row[i].dup.freeze
#   end
# end
#
#
# class MyTable < Table
#   column :name, type: String, readonly: true, unique: true
#   column :number, type: Fixnum
#
#
# end

