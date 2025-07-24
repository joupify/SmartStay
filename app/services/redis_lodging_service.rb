class RedisLodgingService
  INDEX_NAME = "lodgings_idx"

  def initialize(redis: REDIS, openai: OPENAI_CLIENT)
    @redis = redis
    @openai = openai
    create_index_if_not_exists
  end

  # Crée l'index RedisSearch avec un champ vectoriel si pas déjà créé
 def create_index_if_not_exists
  begin
    @redis.call("FT.INFO", INDEX_NAME)
  rescue Redis::CommandError
    @redis.call(
      "FT.CREATE", INDEX_NAME,
      "ON", "HASH",
      "PREFIX", "1", "lodging:",
      "SCHEMA",
      "title", "TEXT",
      "description", "TEXT",
      "price", "NUMERIC",
      "vector", "VECTOR", "FLAT", "6", "TYPE", "FLOAT32", "DIM", "1536", "DISTANCE_METRIC", "COSINE"
    )
  end
end


  # Stocke un logement avec embedding dans Redis
  def save_lodging(id:, title:, description:, price:)
  embedding = generate_embedding("#{title} #{description}")
  # On convertit l’array float en string binaire (float32)
  vector_blob = [embedding].flatten.pack("f*")

  @redis.hset("lodging:#{id}", {
    "title" => title,
    "description" => description,
    "price" => price.to_s,
    "vector" => vector_blob
  })
  @redis.publish("lodgings_channel", { event: "new_lodging", title: title, price: price }.to_json)
  @redis.xadd("lodgings_stream", "*", { title: title, price: price.to_s })


end


# Recherche textuelle simple (fallback)
def search_similar(query, top_k = 5)
  query_downcase = query.to_s.downcase
  all = list_all_lodgings

  all.select do |lodging|
    lodging[:title].to_s.downcase.include?(query_downcase) ||
    lodging[:description].to_s.downcase.include?(query_downcase)
  end.first(top_k)

  cache_key = "search:#{query}"
  cached_results = @redis.get(cache_key)
  return JSON.parse(cached_results, symbolize_names: true) if cached_results

  results = perform_real_search(query) # logique actuelle
  @redis.setex(cache_key, 30, results.to_json)
  results

end


  # Recherche les logements similaires selon une requête textuelle avec openai
#  def search_similar(query, top_k = 5)
#   query_embedding = generate_embedding(query)
#   vector_blob = [query_embedding].flatten.pack("f*")

#   query_str = "*=>[KNN #{top_k} @vector $vec AS vector_score]"
#   params = { "vec" => vector_blob }

#   results = @redis.call("FT.SEARCH", INDEX_NAME, query_str,
#     "PARAMS", "2", "vec", vector_blob,
#     "SORTBY", "vector_score",
#     "RETURN", "3", "title", "description", "price",
#     "DIALECT", "2",
#     "LIMIT", "0", top_k.to_s
#   )

#   count = results.shift
#   lodgings = []

#   results.each_slice(2) do |key, fields_array|
#     # fields_array est un tableau ["title", "value", "description", "value", "price", "value"]
#     fields_hash = Hash[*fields_array]
#     lodgings << {
#       key: key,
#       title: fields_hash["title"],
#       description: fields_hash["description"],
#       price: fields_hash["price"]
#     }
#   end

#   lodgings
# end

def list_all_lodgings
  keys = @redis.keys("lodging:*")
  lodgings = keys.map do |key|
    fields = @redis.hgetall(key)
    {
     key: key,
      title: fields["title"],
      description: fields["description"],
      price: fields["price"]
    }
  end
  lodgings
end






  private

  def generate_embedding(text)

# Mock : génère un vecteur fixe ou aléatoire de taille 1536
  Array.new(1536) { rand }   # vecteur aléatoire, ou
  # Array.new(1536, 0.01)    # vecteur constant, si tu préfères

  
    # response = @openai.embeddings(
    #   parameters: { model: "text-embedding-3-small", input: text }
    # )
    # response["data"][0]["embedding"].map(&:to_f)
  end

  
end

