class Lodging
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :title, :string
  attribute :description, :string
  attribute :price, :float
  attribute :image_url, :string


  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  # Trouve un logement dans Redis
  def self.find(id)
  service = RedisLodgingService.new
  data = service.find_lodging(id)
  return nil unless data

  Lodging.new(
    id: data[:id],           # ici data[:id] au lieu de data[:key]
    title: data[:title],
    description: data[:description],
    price: data[:price],
image_url: data[:image_url] || data["image_url"]

  )
end

  # Met à jour les attributs en mémoire (pas en Redis)
  def update(attrs)
    attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    valid?
  end

  # Retourne un hash compatible avec le service Redis
  def to_h
    {
      id: id,
      title: title,
      description: description,
      price: price,
      image_url: image_url
    }
  end
end
