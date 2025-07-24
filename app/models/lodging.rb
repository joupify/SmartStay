# app/models/lodging.rb
class Lodging
  include ActiveModel::Model

  attr_accessor :id, :title, :description, :price

  validates :title, presence: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  # Optionnel : méthode pour convertir en hash à sauvegarder dans Redis
  def to_h
    {
      id: id,
      title: title,
      description: description,
      price: price.to_s
    }
  end
end
