class Lodging
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :title, :string
  attribute :description, :string
  attribute :price, :float
  attribute :image_url, :string

  validates :id, presence: true
  validates :title, presence: true
  validates :description, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  # ✅ Trouve un logement dans Redis
  def self.find(id)
    service = RedisLodgingService.new
    data = service.find_lodging(id)
    return nil unless data

    Lodging.new(
      id: data["id"] || data[:id],
      title: data["title"] || data[:title],
      description: data["description"] || data[:description],
      price: data["price"] || data[:price],
      image_url: data["image_url"] || data[:image_url]
    )
  end

  # ✅ Mise à jour en mémoire
  def update(attrs)
    attrs.each { |k, v| send("#{k}=", v) if respond_to?("#{k}=") }
    valid?
  end

  # ✅ Conversion en hash
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
