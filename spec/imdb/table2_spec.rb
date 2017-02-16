require 'spec_helper'

module Table2Spec
  class TestTable < IMDB::Table2
    define_columns do
      column :int_col, Fixnum
      column :string_col, String
      column :unique_col, String, unique: true
      column :readonly_col, String, readonly: true
    end
  end

  describe IMDB::Table2 do
    describe "class loaded" do
      it 'defines the columns' do
        expect(TestTable.columns.count).to eq(4)

        int_col = TestTable.get_column(:int_col)
        expect(int_col.data_type_klass).to eq(Fixnum)
        expect(int_col.unique?).to eq(false)
        expect(int_col.readonly?).to eq(false)

        #column is unmodifiable
        expect { int_col.instance_variable_set(:@data_type, String) }.to raise_error("can't modify frozen IMDB::Table2::Column")
        expect { int_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table2::Column")


        string_col = TestTable.get_column(:string_col)
        expect(string_col.data_type_klass).to eq(String)
        expect(string_col.unique?).to eq(false)
        expect(string_col.readonly?).to eq(false)

        #column is unmodifiable
        expect { string_col.instance_variable_set(:@data_type, Fixnum) }.to raise_error("can't modify frozen IMDB::Table2::Column")
        expect { string_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table2::Column")


        unique_col = TestTable.get_column(:unique_col)
        expect(unique_col.data_type_klass).to eq(String)
        expect(unique_col.unique?).to eq(true)
        expect(unique_col.readonly?).to eq(false)

        #column is unmodifiable
        expect { unique_col.instance_variable_set(:@data_type, Fixnum) }.to raise_error("can't modify frozen IMDB::Table2::Column")
        expect { unique_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table2::Column")

        readonly_col = TestTable.get_column(:readonly_col)
        expect(readonly_col.data_type_klass).to eq(String)
        expect(readonly_col.unique?).to eq(false)
        expect(readonly_col.readonly?).to eq(true)

        #column is unmodifiable
        expect { readonly_col.instance_variable_set(:@data_type, Fixnum) }.to raise_error("can't modify frozen IMDB::Table2::Column")
        expect { readonly_col.instance_variable_set(:@name, "different_name") }.to raise_error("can't modify frozen IMDB::Table2::Column")


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
        expect(test_table.instance_variable_get(:@current_index)).to eq(0)
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

          expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0},
                                                                    'unique_col' => {'unique_string' => 0}})
          expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private'])
          expect(test_table.instance_variable_get(:@current_index)).to eq(1)

          #second row
          test_table.insert({'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'another_unique_string', 'readonly_col' => 'still_private'})

          expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0,
                                                                                    'ddc034a9-09a5-48c0-8b26-a1f6359e42f5' => 1},
                                                                     'unique_col' => {'unique_string' => 0,
                                                                                      'another_unique_string' => 1}})
          expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private',
                                                                 6,'King','another_unique_string','still_private'])
          expect(test_table.instance_variable_get(:@current_index)).to eq(2)
        end

        context 'unique key violation' do
          it 'raise UniqueConstraintViolation and does not insert the row or update the indexes' do
            #first row
            test_table.insert({'int_col' => 1, 'string_col' => 'Hi', 'unique_col' => 'unique_string', 'readonly_col' => 'private'})

            expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0},
                                                                       'unique_col' => {'unique_string' => 0}})
            expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private'])
            expect(test_table.instance_variable_get(:@current_index)).to eq(1)

            #second row
            begin
              test_table.insert({'int_col' => 6, 'string_col' => 'King', 'unique_col' => 'unique_string', 'readonly_col' => 'still_private'})
              fail("Should have raised IMDB::UniqueConstraintViolation")
            rescue IMDB::UniqueConstraintViolation => e
              expect(e.column).to eq('unique_col')
              expect(e.value).to eq('unique_string')
            end

            expect(test_table.instance_variable_get(:@indexes)).to eq({'row_uuid' => {'671abb20-ced8-4f1d-87d0-cb4ad16e3a3b' => 0},
                                                                       'unique_col' => {'unique_string' => 0}})
            expect(test_table.instance_variable_get(:@data)).to eq([1,'Hi','unique_string','private'])
            expect(test_table.instance_variable_get(:@current_index)).to eq(1)
          end
        end
      end

      context 'multi threads' do

      end
    end
  end
end
