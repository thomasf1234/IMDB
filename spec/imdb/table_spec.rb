require 'spec_helper'

module TableSpec
  class TestTable < IMDB::Table
    define_columns do
      column :int_col, Fixnum
      column :string_col, String
      column :unique_col, String, unique: true
      column :readonly_col, String, readonly: true
    end
  end

  class TestThread < Thread
    def initialize(name, table, count, start_time)
      @rows = []

      super(name) do
        while row_count < count do
          now = Time.now
          if now > start_time
            row_uuid = table.insert({'int_col' => row_count,
                                     'string_col' => 'Hi this is a string',
                                     'unique_col' => "This is a unique string from row #{row_count} thread #{name}.",
                                     'readonly_col' => 'private'})
            @rows << table.find(row_uuid)
          end
        end
      end
    end

    def rows
      @rows
    end

    def row_count
      @rows.count
    end
  end

  describe IMDB::Table do
    describe "class loaded" do
      it 'defines the columns' do
        expect(TestTable.columns.count).to eq(4)

        int_col = TestTable.get_column(:int_col)
        expect(int_col.data_type_klass).to eq(Fixnum)
        expect(int_col.unique?).to eq(false)
        expect(int_col.readonly?).to eq(false)

        #column is unmodifiable
        expect { int_col.instance_variable_set(:@data_type, String) }.to raise_error("can't modify frozen IMDB::Table::Column")
        expect { int_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table::Column")


        string_col = TestTable.get_column(:string_col)
        expect(string_col.data_type_klass).to eq(String)
        expect(string_col.unique?).to eq(false)
        expect(string_col.readonly?).to eq(false)

        #column is unmodifiable
        expect { string_col.instance_variable_set(:@data_type, Fixnum) }.to raise_error("can't modify frozen IMDB::Table::Column")
        expect { string_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table::Column")


        unique_col = TestTable.get_column(:unique_col)
        expect(unique_col.data_type_klass).to eq(String)
        expect(unique_col.unique?).to eq(true)
        expect(unique_col.readonly?).to eq(false)

        #column is unmodifiable
        expect { unique_col.instance_variable_set(:@data_type, Fixnum) }.to raise_error("can't modify frozen IMDB::Table::Column")
        expect { unique_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table::Column")

        readonly_col = TestTable.get_column(:readonly_col)
        expect(readonly_col.data_type_klass).to eq(String)
        expect(readonly_col.unique?).to eq(false)
        expect(readonly_col.readonly?).to eq(true)

        #column is unmodifiable
        expect { readonly_col.instance_variable_set(:@data_type, Fixnum) }.to raise_error("can't modify frozen IMDB::Table::Column")
        expect { readonly_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table::Column")


        #cannot alter columns
        expect { TestTable.columns[0] = :another_column }.to raise_error("can't modify frozen Array")
        expect { TestTable.columns << :another_column }.to raise_error("can't modify frozen Array")
      end
    end

    describe "#initialize" do
      it 'setups up default variables' do
        test_table = TestTable.new("test_table")

        expect(test_table.name).to eq("test_table")
        expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {}, 'unique_col' => {}})
        expect(test_table.instance_variable_get(:@data)).to eq([])
        expect(test_table.instance_variable_get(:@deleted_row_uuids).empty?).to eq(true)
        expect(test_table.instance_variable_get(:@current_row_index)).to eq(0)
        expect(test_table.instance_variable_get(:@width)).to eq(4)
        expect(test_table.instance_variable_get(:@deleted_row_const)).to eq([nil,nil,nil,nil])
        expect(test_table.instance_variable_get(:@deleted_row_const).frozen?).to eq(true) #unmodifiable
      end
    end

    describe "#insert" do
      let(:test_table) { TestTable.new("test_table") }

      context 'single thread' do
        before :each do
          allow(test_table).to receive(:generate_uuid).and_return('671abb20-ced8-4f1d-87d0-cb4ad16e3a3b', 'ddc034a9-09a5-48c0-8b26-a1f6359e42f5')
        end

        it 'inserts a row and updates the indexes' do
          #first row
          test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          #indexes have been updated with row_uuid and unique_col
          expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0},
                                                                    'unique_col' => {'unique_string' => '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b'}})
          #data stored in single array
          expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private'])
          expect(test_table.instance_variable_get(:@current_row_index)).to eq(1)

          #data within row is frozen so not modifiable
          expect { test_table.instance_variable_get(:@data)[1] << "modifying" }.to raise_error("can't modify frozen String")

          #second row
          test_table.insert({'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'another_unique_string', 'readonly_col' => 'still_private'})

          expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0,
                                                                                    'ddc034a9-09a5-48c0-8b26-a1f6359e42f5' => 1},
                                                                     'unique_col' => {'unique_string' => '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b',
                                                                                      'another_unique_string' => 'ddc034a9-09a5-48c0-8b26-a1f6359e42f5'}})
          expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private',
                                                                 6,'King','another_unique_string','still_private'])
          expect(test_table.instance_variable_get(:@current_row_index)).to eq(2)
        end

        context 'unique key violation' do
          it 'raise UniqueConstraintViolation and does not insert the row or update the indexes' do
            #first row
            test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

            expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0},
                                                                       'unique_col' => {'unique_string' => '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b'}})
            expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private'])
            expect(test_table.instance_variable_get(:@current_row_index)).to eq(1)

            #second row
            begin
              test_table.insert({'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'still_private'})
              fail("Should have raised IMDB::UniqueConstraintViolation")
            rescue IMDB::UniqueConstraintViolation => e
              expect(e.column).to eq('unique_col')
              expect(e.value).to eq('unique_string')
            end

            expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0},
                                                                       'unique_col' => {'unique_string' => '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b'}})
            expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private'])
            expect(test_table.instance_variable_get(:@current_row_index)).to eq(1)
          end
        end
      end

      context 'multi threads' do
        let(:expected_rows_thread1) do
          1000.times.map do |i|
            {
                'int_col' => i,
                'string_col' => "Hi this is a string",
                'unique_col' => "This is a unique string from row #{i} thread thread1.",
                'readonly_col' => "private"
            }
          end
        end

        let(:expected_rows_thread2) do
          1000.times.map do |i|
            {
                'int_col' => i,
                'string_col' => "Hi this is a string",
                'unique_col' => "This is a unique string from row #{i} thread thread2.",
                'readonly_col' => "private"
            }
          end
        end

        let(:expected_rows_thread3) do
          1000.times.map do |i|
            {
                'int_col' => i,
                'string_col' => "Hi this is a string",
                'unique_col' => "This is a unique string from row #{i} thread thread3.",
                'readonly_col' => "private"
            }
          end
        end

        it 'does not create collisions or conflicts regardless of concurrency' do
          start_time = Time.now + 1

          thread1 = TestThread.new('thread1', test_table, 1000, start_time)
          thread2 = TestThread.new('thread2', test_table, 1000, start_time)
          thread3 = TestThread.new('thread3', test_table, 1000, start_time)

          threads = [thread1, thread2, thread3]
          threads.each(&:join) # wait for all threads to finish


          expect(thread1.rows.count).to eq(1000)
          expect(thread1.rows).to eq(expected_rows_thread1)

          expect(thread2.rows.count).to eq(1000)
          expect(thread2.rows).to eq(expected_rows_thread2)

          expect(thread3.rows.count).to eq(1000)
          expect(thread3.rows).to eq(expected_rows_thread3)
        end
      end
    end

    describe "#find" do
      let(:test_table) { TestTable.new("test_table") }

      context 'row exists' do
        it 'retrieves a snapshot of the row to avoid contamination of the database' do
          row_uuid = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          row = test_table.find(row_uuid)
          expect(row).to eq({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          #doesn't contaminate database
          row['int_col'] = 2
          row['unique_string'] = 2
          expect(test_table.find(row_uuid)).to eq({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
        end
      end

      context 'row does not exist' do
        it 'throws RowNotFound exception' do
          begin
            test_table.find("671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
            fail("Should have thrown IMDB::RowNotFound")
          rescue IMDB::RowNotFound => e
            expect(e.search_params).to eq(row_uuid: "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
          end
        end
      end
    end

    describe "#find_by" do
      let(:test_table) { TestTable.new("test_table") }

      context 'row exists' do
        it 'retrieves a snapshot of the row to avoid contamination of the database' do
          row_uuid = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          row = test_table.find_by('unique_col', 'unique_string')
          expect(row).to eq({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          #doesn't contaminate database
          row['int_col'] = 2
          row['unique_string'] = 2
          expect(test_table.find(row_uuid)).to eq({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
        end
      end

      context 'row does not exist' do
        it 'throws RowNotFound exception' do
          begin
            test_table.find_by('unique_col', 'unique_string')
            fail("Should have thrown IMDB::RowNotFound")
          rescue IMDB::RowNotFound => e
            expect(e.search_params).to eq('unique_col' => 'unique_string')
          end
        end
      end
    end

    describe "#update" do
      let(:test_table) { TestTable.new("test_table") }

      context 'row exists' do
        it 'retrieves a snapshot of the row to avoid contamination of the database' do
          row_uuid = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          test_table.update(row_uuid, {'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

          expect(test_table.find(row_uuid)).to eq({'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
        end

        context 'unique constraint violation' do
          it 'throws UniqueConstrainViolation exception' do
            row_uuid1 = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
            row_uuid2 = test_table.insert({'int_col' => 2, 'string_col' => 'Hi', 'unique_col' => 'another_unique_string', 'readonly_col' => 'private'})

            begin
              test_table.update(row_uuid2, {'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
              fail("Should have raised IMDB::UniqueConstraintViolation")
            rescue IMDB::UniqueConstraintViolation => e
              expect(e.column).to eq('unique_col')
              expect(e.value).to eq('unique_string')
            end

            expect(test_table.find(row_uuid2)).to eq({'int_col' => 2, 'string_col' => 'Hi', 'unique_col' => 'another_unique_string', 'readonly_col' => 'private'})
            expect(test_table.find_by('unique_col','another_unique_string')).to eq({'int_col' => 2, 'string_col' => 'Hi', 'unique_col' => 'another_unique_string', 'readonly_col' => 'private'})
          end
        end

        context 'readonly column' do
          it 'does not update the readonly column' do
            row_uuid = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
            test_table.update(row_uuid, {'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'still_private'})

            expect(test_table.find(row_uuid)).to eq({'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
          end
        end
      end

      context 'row does not exist' do
        it 'throws RowNotFound exception' do
          begin
            test_table.update("671abb20-ced8-4f1d-87d0-cb4ad16e3a3b", {'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'another_unique_string', 'readonly_col' => 'still_private'})
            fail("Should have thrown IMDB::RowNotFound")
          rescue IMDB::RowNotFound => e
            expect(e.search_params).to eq('row_uuid' => '671abb20-ced8-4f1d-87d0-cb4ad16e3a3b')
          end
        end
      end
    end

    describe "delete" do
      let(:test_table) { TestTable.new("test_table") }

      it 'marks the row as deleted' do
        row_uuid1 = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
        row_uuid2 = test_table.insert({'int_col' => 2, 'string_col' => 'Hi2', 'unique_col' => 'unique_string2', 'readonly_col' => 'private2'})
        test_table.delete(row_uuid1)

        begin
          test_table.find(row_uuid1)
          fail("Should have thrown IMDB::RowDeleted")
        rescue IMDB::RowDeleted => e
          expect(e.row_uuid).to eq(row_uuid1)
        end

        expect(test_table.instance_variable_get(:@data)).to eq([nil, nil, nil, nil,
                                                                2,'Hi2','unique_string2','private2'])
      end

      context 'row already deleted' do
        it 'raises RowDeleted exception' do
          row_uuid = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
          test_table.delete(row_uuid)

          begin
            test_table.delete(row_uuid)
            fail("Should have thrown IMDB::RowDeleted")
          rescue IMDB::RowDeleted => e
            expect(e.row_uuid).to eq(row_uuid)
          end

          expect(test_table.instance_variable_get(:@data)).to eq([nil, nil, nil, nil])
        end
      end

      context 'row doesnt exist' do
        it 'raises RowNotFound exception' do
          begin
            test_table.delete("671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
            fail("Should have thrown IMDB::RowNotFound")
          rescue IMDB::RowNotFound => e
            expect(e.search_params).to eq('row_uuid' => "671abb20-ced8-4f1d-87d0-cb4ad16e3a3b")
          end

          expect(test_table.instance_variable_get(:@data)).to eq([])
        end
      end
    end

    describe "#empty?" do
      let(:test_table) { TestTable.new("test_table") }

      context 'no rows inserted' do
        it 'returns true' do
          expect(test_table.empty?).to eq(true)
        end
      end

      context 'rows inserted' do
        it 'returns false' do
          row_uuid1 = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
          expect(test_table.empty?).to eq(false)

          row_uuid2 = test_table.insert({'int_col' => 2, 'string_col' => 'Hi2', 'unique_col' => 'unique_string2', 'readonly_col' => 'private2'})
          expect(test_table.empty?).to eq(false)
        end
      end

      context 'rows inserted but some deleted' do
        it 'returns false' do
          row_uuid1 = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
          expect(test_table.empty?).to eq(false)

          row_uuid2 = test_table.insert({'int_col' => 2, 'string_col' => 'Hi2', 'unique_col' => 'unique_string2', 'readonly_col' => 'private2'})
          test_table.delete(row_uuid2)
          expect(test_table.empty?).to eq(false)
        end
      end

      context 'rows inserted and all deleted' do
        it 'returns true' do
          row_uuid1 = test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})
          expect(test_table.empty?).to eq(false)

          row_uuid2 = test_table.insert({'int_col' => 2, 'string_col' => 'Hi2', 'unique_col' => 'unique_string2', 'readonly_col' => 'private2'})
          test_table.delete(row_uuid1)
          test_table.delete(row_uuid2)
          expect(test_table.empty?).to eq(true)
          expect(test_table.instance_variable_get(:@data)).to eq([nil,nil,nil,nil,
                                                                 nil,nil,nil,nil])
        end
      end
    end

    describe "p#get_range" do
      let(:test_table) { TestTable.new("test_table") }

      it 'returns the range defining the boundaries of the row at given table_index' do
        expect(test_table.send(:get_range, 0)).to eq(0..3)
        expect(test_table.send(:get_range, 1)).to eq(4..7)
        expect(test_table.send(:get_range, 2)).to eq(8..11)
        expect(test_table.send(:get_range, 3)).to eq(12..15)
        expect(test_table.send(:get_range, 4)).to eq(16..19)
      end
    end
  end
end
