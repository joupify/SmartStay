class RedisLodgingService
  require 'digest'

  INDEX_NAME = "lodgings_idx"

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
      image_url: fields["image_url"]  # <-- Ajouté ici

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
      "RETURN", "4", "title", "description", "price", "vector_score",
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
        price: fields_hash["price"],
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

      lodgings << {
        key: key,
        title: data["title"],
        description: data["description"],
        price: data["price"]
      }
    end
    lodgings
  end

  private

  # ✅ Mock embedding si OpenAI absent
  def generate_embedding(text)
    if ENV["OPENAI_API_KEY"].nil? || @openai.nil?
      return Array.new(1536, text.include?("paris") ? 0.9 : 0.1)
    end

    response = @openai.embeddings(parameters: {
      model: "text-embedding-3-small",
      input: text
    })
    response["data"][0]["embedding"]
  rescue
    Array.new(1536, 0.1)
  end

  # ✅ Broadcast unifié (Streams + Pub/Sub + ActionCable)
 def broadcast(action, data)
  lodging_data = data.transform_keys(&:to_s)
  flat_event = lodging_data.merge("action" => action)
  @redis.xadd("lodgings_stream", flat_event, id: "*")
  @redis.publish("lodgings_channel", { "action" => action, "lodging" => lodging_data }.to_json)
  ActionCable.server.broadcast("lodgings_channel", { "action" => action, "lodging" => lodging_data })
end

end
