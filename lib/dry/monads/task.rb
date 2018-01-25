require 'concurrent/promise'

module Dry
  module Monads
    class Task
      def self.new(promise = nil, &block)
        if block
          super(Concurrent::Promise.execute(&block))
        else
          super(promise)
        end
      end

      attr_reader :promise
      protected :promise

      def initialize(promise)
        @promise = promise
      end

      def value!
        promise.wait
        if promise.fulfilled?
          promise.value
        else
          raise UnwrapError.new(self)
        end
      end

      def fmap(&block)
        self.class.new(@promise.then(&block))
      end

      def bind(&block)
        self.class.new(@promise.flat_map { |value| block.(value).promise })
      end

      def to_result
        promise.wait

        if promise.fulfilled?
          Result::Success.new(promise.value)
        else
          Result::Failure.new(promise.reason)
        end
      end

      def to_maybe
        Maybe.coerce(promise.value)
      end

      def to_s
        state, internal = case promise.state
                          when :fulfilled
                            ['resolved', " value=#{ value!.inspect }"]
                          when :rejected
                            ['rejected', " error=#{ promise.reason.inspect }"]
                          else
                            'pending'
                          end

        "Task(state=#{ state }#{ internal })"
      end
      alias_method :inspect, :to_s
    end
  end
end
