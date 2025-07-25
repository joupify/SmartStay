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
        "vector", "VECTOR", "FLAT", "6",
        "TYPE", "FLOAT32", "DIM", "1536", "DISTANCE_METRIC", "COSINE"
      )
    end
  end

  # Stocke un logement avec embedding dans Redis
  def save_lodging(id:, title:, description:, price:)
    embedding = generate_embedding("#{title} #{description}")
    vector_blob = [embedding].flatten.pack("f*")

    @redis.hset("lodging:#{id}", {
      "title" => title,
      "description" => description,
      "price" => price.to_s,
      "vector" => vector_blob
    })

    # Publier événement pub/sub
    payload = { event: "new_lodging", id: id, title: title }.to_json
    Rails.logger.info "Publishing to lodgings_channel: #{payload}"
    @redis.publish("lodgings_channel", payload)

    @redis.publish("lodgings_channel", { event: "new_lodging", id: id, title: title }.to_json)
    ActionCable.server.broadcast("lodgings_channel", { event: "new_lodging", id: id, title: title })


    # Ajouter au stream pour historique
    @redis.xadd("lodgings_stream", { id: id, title: title, price: price.to_s }, id: "*")

    # Initialiser popularité à 0 si pas déjà présente
    @redis.zadd("lodgings_popularity", 0, id)
  end

  def text_search(query, limit = 5)
  results = @redis.call("FT.SEARCH", INDEX_NAME, query, "LIMIT", "0", limit.to_s)
  count = results.shift
  lodgings = []

  results.each_slice(2) do |key, fields_array|
    fields_hash = Hash[*fields_array]
    lodgings << {
      key: key,
      title: fields_hash["title"],
      description: fields_hash["description"],
      price: fields_hash["price"]
    }
  end

  lodgings
end


  # Recherche textuelle simple (fallback)
  def search_similar(query, top_k = 5)
    cache_key = "search:#{query.downcase}"
    cached_results = @redis.get(cache_key)
    if cached_results
      # Retourne le cache parsé (symbolize_names pour avoir des symboles en clé)
      return JSON.parse(cached_results, symbolize_names: true)
    end

    # Générer l'embedding pour la recherche vectorielle
    query_embedding = generate_embedding(query)
    vector_blob = [query_embedding].flatten.pack("f*")

    query_str = "*=>[KNN #{top_k} @vector $vec AS vector_score]"
    
    results = @redis.call("FT.SEARCH", INDEX_NAME, query_str,
      "PARAMS", "2", "vec", vector_blob,
      "SORTBY", "vector_score",
      "RETURN", "3", "title", "description", "price",
      "DIALECT", "2",
      "LIMIT", "0", top_k.to_s
    )

    count = results.shift
    lodgings = []

    results.each_slice(2) do |key, fields_array|
      fields_hash = Hash[*fields_array]
      lodgings << {
        key: key,
        title: fields_hash["title"],
        description: fields_hash["description"],
        price: fields_hash["price"]
      }
    end

    # Sauvegarder le résultat dans Redis avec TTL 30 secondes
    @redis.setex(cache_key, 30, lodgings.to_json)

    lodgings
  end


  # Recherche vectorielle (commentée, à décommenter pour usage réel)
  # def search_similar(query, top_k = 5)
  #   query_embedding = generate_embedding(query)
  #   vector_blob = [query_embedding].flatten.pack("f*")
  #
  #   query_str = "*=>[KNN #{top_k} @vector $vec AS vector_score]"
  #
  #   results = @redis.call("FT.SEARCH", INDEX_NAME, query_str,
  #     "PARAMS", "2", "vec", vector_blob,
  #     "SORTBY", "vector_score",
  #     "RETURN", "3", "title", "description", "price",
  #     "DIALECT", "2",
  #     "LIMIT", "0", top_k.to_s
  #   )
  #
  #   count = results.shift
  #   lodgings = []
  #
  #   results.each_slice(2) do |key, fields_array|
  #     fields_hash = Hash[*fields_array]
  #     lodgings << {
  #       key: key,
  #       title: fields_hash["title"],
  #       description: fields_hash["description"],
  #       price: fields_hash["price"]
  #     }
  #   end
  #
  #   lodgings
  # end

  # Liste tous les logements
  def list_all_lodgings
    keys = @redis.keys("lodging:*")
    keys.map do |key|
      fields = @redis.hgetall(key)
      {
        key: key,
        title: fields["title"],
        description: fields["description"],
        price: fields["price"]
      }
    end
  end

  # Incrémente la popularité
  def increment_popularity(lodging_key)
    @redis.zincrby("lodgings_popularity", 1, lodging_key)
  end

  # Retourne les top logements populaires
  def top_popular_lodgings(limit = 5)
    ids = @redis.zrevrange("lodgings_popularity", 0, limit - 1)
    lodgings = []
    ids.each do |key|
      data = @redis.call("FT.SEARCH", INDEX_NAME, "@__key:#{key}", "RETURN", "3", "title", "description", "price", "LIMIT", "0", "1")
      next if data.empty?

      title = data[2]
      description = data[4]
      price = data[6]
      lodgings << { key: key, title: title, description: description, price: price }
    end
    lodgings
  end

  private

  # Génère un embedding simulé (mock)
  def generate_embedding(text)
    # Mock : vecteur aléatoire 1536 dimensions
    Array.new(1536) { rand }
    # ou vecteur constant si tu préfères
    # Array.new(1536, 0.01)

    # OpenAI embedding (commenté)
    # response = @openai.embeddings(
    #   parameters: { model: "text-embedding-3-small", input: text }
    # )
    # response["data"][0]["embedding"].map(&:to_f)
  end
end
