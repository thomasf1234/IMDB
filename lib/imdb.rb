module IMDB
  VERSION = '0.0.0'
end

require 'imdb/lock'
require 'imdb/exception'
require 'imdb/exceptions/row_not_found'
require 'imdb/exceptions/unique_constraint_violation'
require 'imdb/exceptions/row_deleted'
require 'imdb/table'
