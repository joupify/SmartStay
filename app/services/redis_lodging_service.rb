require 'digest'

class RedisLodgingService
  INDEX_NAME = "lodgings_idx"
  EMBEDDING_CACHE_TTL = 24.hours.to_i

  def initialize(redis: REDIS, openai: OPENAI_CLIENT)
    @redis = redis
    @openai = openai
    create_index_if_not_exists
  end

  # ✅ Crée l'index RediSearch si inexistant
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
        "image_url", "TEXT",
        "vector", "VECTOR", "FLAT", "6",
        "TYPE", "FLOAT32", "DIM", "1536", "DISTANCE_METRIC", "COSINE"
      )
    end
  end

  # ✅ Ajout d’un logement
  def save_lodging(id:, title:, description:, price:, image_url: nil)
    key = "lodging:#{id}"

    embedding = generate_embedding("#{title} #{description}")
    vector_blob = embedding.pack("e*") # Float32

    @redis.hset(key, {
      "title" => title,
      "description" => description,
      "price" => price.to_s,
      "vector" => vector_blob,
      "image_url" => image_url || "https://source.unsplash.com/400x300/?apartment"
    })

    @redis.zadd("lodgings_popularity", 0, key)

    # 🔔 Notifications
    broadcast("created", { id: id, title: title, description: description, price: price.to_s, image_url: image_url })

    true
  end

  # ✅ Lire un logement
  def find_lodging(id)
    key = "lodging:#{id}"
    fields = @redis.hgetall(key)
    return nil if fields.empty?

    {
      id: id,
      title: fields["title"],
      description: fields["description"],
      price: fields["price"],
      image_url: fields["image_url"]
    }
  end

  def show_lodging(id)
    find_lodging(id)
  end

  # ✅ Mise à jour
  def update_lodging(id, attrs)
    key = "lodging:#{id}"
    flat_attrs = attrs.to_h.to_a.flatten.map(&:to_s)
    return false if flat_attrs.empty?

    @redis.hmset(key, *flat_attrs)

    updated_data = find_lodging(id)
    broadcast("updated", updated_data)

    true
  end

  # ✅ Suppression
  def delete_lodging(id)
    key = "lodging:#{id}"
    lodging_data = @redis.hgetall(key)

    @redis.del(key)
    @redis.zrem("lodgings_popularity", key)

    broadcast("deleted", {
      id: id,
      title: lodging_data["title"] || "(inconnu)"
    })

    true
  end

  # ✅ Liste complète
  def list_all_lodgings
    keys = @redis.keys("lodging:*")
    keys.map do |key|
      fields = @redis.hgetall(key)
      id = key.sub("lodging:", "")
      {
        id: id,
        title: fields["title"],
        description: fields["description"],
        price: fields["price"],
        image_url: fields["image_url"]
      }
    end
  end

  # ✅ Recherche texte
  def text_search(query, limit = 5)
    results = @redis.call("FT.SEARCH", INDEX_NAME, query, "LIMIT", "0", limit.to_s)
    count = results.shift
    lodgings = []

    results.each_slice(2) do |key, fields_array|
      fields_hash = Hash[*fields_array]
      lodgings << {
        key: key,
        id: key.sub("lodging:", ""),
        title: fields_hash["title"],
        description: fields_hash["description"],
        price: fields_hash["price"],
        image_url: fields_hash["image_url"]
      }
    end
    lodgings
  end

  # ✅ Recherche vectorielle (IA)
  def search_similar(query, top_k = 5)
    query_embedding = generate_embedding(query)
    vector_blob = query_embedding.pack("e*")

    query_str = "*=>[KNN #{top_k} @vector $vec AS vector_score]"
    results = @redis.call(
      "FT.SEARCH", INDEX_NAME, query_str,
      "PARAMS", "2", "vec", vector_blob,
      "SORTBY", "vector_score",
      "RETURN", "5", "title", "description", "price", "image_url", "vector_score",
      "DIALECT", "2",
      "LIMIT", "0", top_k.to_s
    )

    count = results.shift
    lodgings = []
    results.each_slice(2) do |key, fields_array|
      fields_hash = Hash[*fields_array]
      lodgings << {
        key: key,
        id: key.sub("lodging:", ""),
        title: fields_hash["title"],
        description: fields_hash["description"],
        price: fields_hash["price"],
        image_url: fields_hash["image_url"],
        vector_score: fields_hash["vector_score"]
      }
    end
    lodgings
  end

  # ✅ Popularité
  def increment_popularity(lodging_key)
    @redis.zincrby("lodgings_popularity", 1, lodging_key)
  end

  def top_popular_lodgings(limit = 5)
    ids = @redis.zrevrange("lodgings_popularity", 0, limit - 1)
    lodgings = []
    ids.each do |key|
      data = @redis.hgetall(key)
      next if data.empty?

      id = key.sub("lodging:", "")
      lodgings << {
        id: id,
        key: key,
        title: data["title"],
        description: data["description"],
        price: data["price"],
        image_url: data["image_url"]
      }
    end
    lodgings
  end

  private

  # ✅ Mock embedding si OpenAI absent
  def generate_embedding(text)
    return mock_embedding(text) if should_mock?

    cached_embedding = get_cached_embedding(text)
    return cached_embedding if cached_embedding

    generate_and_cache_embedding(text)
  rescue => e
    Rails.logger.error("Embedding generation failed: #{e}")
    mock_embedding(text)
  end

  def should_mock?
    ENV["OPENAI_API_KEY"].nil? || @openai.nil?
  end

  def mock_embedding(text)
    Array.new(1536, text.downcase.include?("paris") ? 0.9 : 0.1)
  end

  def get_cached_embedding(text)
    cache_key = "embedding:#{Digest::SHA256.hexdigest(text)}"
    cached = @redis.get(cache_key)
    Marshal.load(cached) rescue nil
  end

  def generate_and_cache_embedding(text)
    response = @openai.embeddings(parameters: {
      model: "text-embedding-3-small",
      input: text
    })

    embedding = response["data"][0]["embedding"]
    cache_key = "embedding:#{Digest::SHA256.hexdigest(text)}"
    @redis.setex(cache_key, EMBEDDING_CACHE_TTL, Marshal.dump(embedding))

    embedding
  end

  # ✅ Broadcast unifié (Streams + Pub/Sub + ActionCable)
  def broadcast(action, data)
    lodging_data = data.transform_keys(&:to_s)
    flat_event = lodging_data.merge("action" => action)

    # Ajout de l'événement dans le Stream
    @redis.xadd("lodgings_stream", flat_event, id: "*")

    # ✅ Limite à 50 événements max
    @redis.xtrim("lodgings_stream", "MAXLEN", "~", 50)

    # Notifications en temps réel
    @redis.publish("lodgings_channel", { "action" => action, "lodging" => lodging_data }.to_json)
    ActionCable.server.broadcast("lodgings_channel", { "action" => action, "lodging" => lodging_data })
  end
end
