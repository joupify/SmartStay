class RecommendationsController < ApplicationController
  def index
    @service = RedisLodgingService.new
    if params[:query].present?
      @results = @service.search_similar(params[:query])
    else
      @results = []
    end

  end
end
