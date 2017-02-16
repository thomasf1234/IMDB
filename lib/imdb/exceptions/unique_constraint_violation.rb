class IMDB::UniqueConstraintViolation < IMDB::Exception
  attr_reader :column, :value

  def initialize(column, value)
    super("Row already found for column #{column} with value #{value}")
    @column = column
    @value = value
  end
end