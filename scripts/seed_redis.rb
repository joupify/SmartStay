# scripts/seed_redis.rb
require 'redis'
require 'json'

redis = Redis.new(host: "localhost", port: 6380)

# Mock embedding : vecteur 1536 dimensions rempli de 0.01
def generate_mock_embedding
  Array.new(1536, 0.01)
end

def pack_vector(embedding)
  embedding.pack("f*")
end

lodgings = [
  { id: 1, title: "Appartement cosy Paris", description: "Charmant T2 proche centre", price: 120 },
  { id: 2, title: "Loft moderne Lyon", description: "Grand espace lumineux", price: 150 },
  { id: 3, title: "Studio étudiant Bordeaux", description: "Petite surface, bien situé", price: 70 },
  { id: 4, title: "Villa piscine Nice", description: "Luxueuse villa avec piscine", price: 300 },
  { id: 5, title: "Chambre simple Marseille", description: "Chambre privée dans colocation", price: 50 }
]

lodgings.each do |lodging|
  embedding = generate_mock_embedding
  vector_blob = pack_vector(embedding)
  
  redis.hset("lodging:#{lodging[:id]}", {
    "title" => lodging[:title],
    "description" => lodging[:description],
    "price" => lodging[:price].to_s,
    "vector" => vector_blob
  })
  
  puts "Inserted lodging #{lodging[:id]}: #{lodging[:title]}"
end


# ruby scripts/seed_redis.rb
