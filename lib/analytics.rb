require 'redis'
require_relative 'analytics/page'

module Analytics
  def self.store
    @redis ||= Redis.new(
      host: ENV["REDIS_PORT_6379_TCP_ADDR"],
      port: ENV["REDIS_PORT_6379_TCP_PORT"]
    )
  end
end

