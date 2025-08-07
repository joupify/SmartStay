require 'redis'
require 'securerandom'

redis = Redis.new(host: 'localhost', port: 6380)

puts "Deleting all keys matching lodging:*"
keys = redis.keys("lodging:*")
redis.del(*keys) unless keys.empty?
puts "Inserting test lodgings..."
lodgings = [
  { id: SecureRandom.uuid, title: "Cozy apartment in Paris", description: "Charming one-bedroom near city center", price: 120, image_url: "img1.png" },
  { id: SecureRandom.uuid, title: "Modern loft in Lyon", description: "Spacious and bright", price: 150, image_url: "img2.png" },
  { id: SecureRandom.uuid, title: "Student studio in Bordeaux", description: "Small but well-located", price: 70, image_url: "img3.png" },
  { id: SecureRandom.uuid, title: "Villa with pool in Nice", description: "Luxurious villa with swimming pool", price: 300, image_url: "img4.png" },
  { id: SecureRandom.uuid, title: "Single room in Marseille", description: "Private room in shared apartment", price: 50, image_url: "img5.jpg" },
  { id: SecureRandom.uuid, title: "Forest Cabin in Alsace", description: "Peaceful nature getaway", price: 90, image_url: "img6.jpg" }

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

puts "Seed Redis complete!"
