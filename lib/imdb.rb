module IMDB
  VERSION = '0.0.0'
end

require 'imdb/lock'
require 'imdb/row_uuid_sequence'
require 'imdb/row'
require 'imdb/table'
require 'imdb/table2'
require 'imdb/exception'
require 'imdb/exceptions/row_not_found'
require 'imdb/exceptions/unique_constraint_violation'
