require 'terrafying/dynamodb/named_lock'

module Terrafying
  module Locks
    class NoOpLock
      def acquire
        ""
      end
      def steal
        ""
      end
      def release(lock_id)
      end
    end

    def self.noop
      NoOpLock.new
    end

    def self.dynamodb(scope)
      Terrafying::DynamoDb::NamedLock.new("terrafying-state-lock", scope)
    end

  end
end
