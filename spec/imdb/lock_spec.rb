require 'spec_helper'

module LockSpec
  class TestLock
    include IMDB::Lock

    attr_reader :diff

    def initialize
      @count1 = 0
      @count2 = 0
      @diff = 0
    end

    def increment_count
      lock do
        @count1 += 1
        sleep(0.001)
        @count2 += 1
      end
    end

    def increment_diff
      lock do
        @diff += (@count2 - @count1).abs
      end
    end
  end

  class Helper
    def self.within_interval(start_time, end_time)
      loop do
        now = Time.now

        if now > end_time
          break
        elsif now > start_time
          yield
        end
      end
    end
  end

  describe IMDB::Lock do
    describe "#lock" do
      it 'allows only one thread at a time to acquire lock' do
        test_lock = TestLock.new
        threads = []
        start_time = Time.now + 2
        end_time = Time.now + 3

        threads << Thread.new do
          Helper.within_interval(start_time, end_time) { test_lock.increment_count }
        end

        threads << Thread.new do
          Helper.within_interval(start_time, end_time) { test_lock.increment_diff }
        end

        threads.each(&:join) # wait for all threads to finish
        expect(test_lock.diff).to eq(0)
      end
    end
  end
end

