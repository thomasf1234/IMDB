class IMDB::RowDeleted < IMDB::Exception
  def initialize(row_uuid)
    super("Attempt to interact with a row has been marked as deleted")
    @row_uuid = row_uuid
  end

  def row_uuid
    @row_uuid
  end
end