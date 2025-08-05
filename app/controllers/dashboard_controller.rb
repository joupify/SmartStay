class DashboardController < ApplicationController
  def index
    @total_lodgings = REDIS.keys("lodging:*").size
    @top_lodgings = RedisLodgingService.new.top_popular_lodgings(5)
    @stream_count = REDIS.xlen("lodgings_stream")
    @recent_events = REDIS.xrevrange("lodgings_stream", "+", "-", count: 5)
  end
end
