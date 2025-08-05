require 'redis'
require 'securerandom'

redis = Redis.new(host: 'localhost', port: 6380)

puts "Suppression des clés lodging:*"
keys = redis.keys("lodging:*")
redis.del(*keys) unless keys.empty?

puts "Insertion des logements de test..."
lodgings = [
  { id: SecureRandom.uuid, title: "Appartement cosy Paris", description: "Charmant T2 proche centre", price: 120, image_url: "img1.png" },
  { id: SecureRandom.uuid, title: "Loft moderne Lyon", description: "Grand espace lumineux", price: 150, image_url: "img2.png" },
  { id: SecureRandom.uuid, title: "Studio étudiant Bordeaux", description: "Petite surface, bien situé", price: 70, image_url: "img3.png" },
  { id: SecureRandom.uuid, title: "Villa piscine Nice", description: "Luxueuse villa avec piscine", price: 300, image_url: "img4.png" },
  { id: SecureRandom.uuid, title: "Chambre simple Marseille", description: "Chambre privée dans colocation", price: 50, image_url: "img5.jpg" }
]


def pack_vector(embedding)
  embedding.pack("f*")
end

def generate_mock_embedding
  Array.new(1536, 0.01)
end

lodgings.each do |lodging|
  embedding = generate_mock_embedding
  vector_blob = pack_vector(embedding)

  redis.hset("lodging:#{lodging[:id]}", {
    "title" => lodging[:title],
    "description" => lodging[:description],
    "price" => lodging[:price].to_s,
    "vector" => vector_blob,
    "image_url" => lodging[:image_url]
  })

  puts "Inserted lodging #{lodging[:id]}: #{lodging[:title]}"
end

puts "Seed Redis terminé !"
