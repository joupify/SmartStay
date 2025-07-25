class LodgingsController < ApplicationController
  def index
    @service = RedisLodgingService.new
    if params[:query].present?
      @lodgings = @service.search_similar(params[:query])
    else
      @lodgings = @service.list_all_lodgings 
    end

    @top_lodgings = @service.top_popular_lodgings
  end


  def new
  @lodging = Lodging.new
    # Juste afficher le formulaire
  end

 def create
  @lodging = Lodging.new(lodging_params)
  @lodging.id = SecureRandom.uuid

  if @lodging.valid?
    # Sauvegarde dans Redis via le service
    RedisLodgingService.new.save_lodging(**@lodging.to_h)
     Rails.logger.info "Logement créé : #{@lodging.inspect}"

    redirect_to lodgings_path, notice: "Logement ajouté avec succès !"
  else
    render :new, status: :unprocessable_entity
  end



end

private

def lodging_params
  params.permit(:title, :description, :price)
end

end

