class LodgingsController < ApplicationController
  before_action :set_service
  before_action :set_lodging, only: [:edit, :update, :destroy]

  def index
  @service = RedisLodgingService.new

  if params[:query].present?
    # Appel direct de la méthode du service
    search_results = @service.text_search(params[:query])
    
    # Formatage des résultats pour la vue
    @lodgings = search_results.map do |result|
      {
        id: result[:key]&.split(':').last, # Extraction de l'ID
        title: result[:title],
        description: result[:description],
        price: result[:price]
      }
    end
  else
    @lodgings = @service.list_all_lodgings
  end

  # Récupération des tops logements
  @top_lodgings = @service.top_popular_lodgings
end

  def show
    @lodging = @service.find_lodging(params[:id])
    @service.increment_popularity("lodging:#{params[:id]}") if @lodging

    if @lodging.nil?
      redirect_to lodgings_path, alert: "Logement non trouvé."
    end
  end

  def new
    @lodging = Lodging.new
  end

 def edit
  data = RedisLodgingService.new.find_lodging(params[:id])
  if data
    @lodging = Lodging.new(data)
    @lodging.id = params[:id]
  else
    redirect_to lodgings_path, alert: "Logement introuvable"
  end
end


  def create
    @lodging = Lodging.new(lodging_params)
    @lodging.id = SecureRandom.uuid

    if @lodging.valid?
      @service.save_lodging(**@lodging.to_h)

      redirect_to lodgings_path, notice: "Logement ajouté avec succès !"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @service.update_lodging(@lodging.id, lodging_params.to_h)

      redirect_to lodgings_path, notice: "Logement mis à jour avec succès !"
    else
      redirect_to lodgings_path, alert: "Erreur lors de la mise à jour du logement."
    end
  end

 def destroy
  id = params[:id]   # Récupération de l'id de la route
  service = RedisLodgingService.new

  if service.delete_lodging(id)

    redirect_to lodgings_path, notice: "Logement supprimé avec succès !"
  else
    redirect_to lodgings_path, alert: "Erreur lors de la suppression."
  end
end

  def similar
    @service = RedisLodgingService.new
    lodging = @service.find_lodging(params[:id])
    @lodgings = @service.search_similar("#{lodging[:title]} #{lodging[:description]}")
  end



  private

  def set_service
    @service = RedisLodgingService.new
  end

  def set_lodging
    @lodging = Lodging.find(params[:id])
  end

  def lodging_params
    params.require(:lodging).permit(:title, :description, :price, :image_url)
  end



end
