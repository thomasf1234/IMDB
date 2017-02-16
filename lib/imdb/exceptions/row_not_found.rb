class IMDB::RowNotFound < IMDB::Exception
  def initialize(search_params)
    super("Could not find row with search params passed")
    @search_params = search_params
  end

  def search_params
    @search_params
  end
end