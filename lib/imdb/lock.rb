module IMDB
  module Lock
    def lock
      lock_mutex.synchronize do
        yield
      end
    end

    def lock_mutex
      @lock_mutex ||= Mutex.new
    end
  end
end