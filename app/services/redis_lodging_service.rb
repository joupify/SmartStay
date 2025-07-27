class RedisLodgingService
  require 'digest'

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
  # Sauvegarder un logement
  def save_lodging(id:, title:, description:, price:)
    key = "lodging:#{id}"

    # Génération embedding (simulée ici)
    embedding = generate_embedding("#{title} #{description}")
    vector_blob = embedding.pack("e*") # Format Float32 little-endian

    # Sauvegarde dans un hash Redis
    @redis.hset(key, {
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
    # ActionCable.server.broadcast("lodgings_channel", { event: "new_lodging", id: id, title: title })


  # Broadcast (Stream + Pub/Sub + ActionCable)
# 🔔 Broadcast après création
  broadcast("created", {
    id: id,
    title: title,
    description: description,
    price: price.to_s
  })

    # Initialisation popularité si non existant
    @redis.zadd("lodgings_popularity", 0, key)

    # Ajout au stream (historique des événements)
    @redis.xadd("lodgings_stream", { id: key, title: title, price: price.to_s }, id: "*")

    true
  end

def find_lodging(id)
    key = "lodging:#{id}"
    fields = @redis.hgetall(key)
  return nil if fields.empty?

  {
    id: id,
    title: fields["title"],
    description: fields["description"],
    price: fields["price"]
  }
end


  # 👁️ Afficher un logement (alias)
  def show_lodging(id)
    find_lodging(id)
  end

  # ✏️ Mettre à jour un logement
  def update_lodging(id, attrs)
    key = "lodging:#{id}"
    flat_attrs = attrs.to_h.to_a.flatten.map(&:to_s)
    return false if flat_attrs.empty?

    @redis.hmset(key, *flat_attrs)

  # Broadcast
  # 🔔 Broadcast après mise à jour
  updated_data = find_lodging(id)
  broadcast("updated", updated_data)

    
    true
  end

  # ❌ Supprimer un logement
  def delete_lodging(id)
    key = "lodging:#{id}"
    @redis.del(key)
    @redis.zrem("lodgings_popularity", key)

    
  
  # 🔔 Broadcast après suppression
  broadcast("deleted", { id: id })
    true
  end

  # 📜 Lister tous les logements
  def list_all_lodgings
    keys = @redis.keys("lodging:*")
    keys.map do |key|
      fields = @redis.hgetall(key)
      id = key.sub("lodging:", "") # ✅ supprime le préfixe
      {
        id: id,
        title: fields["title"],
        description: fields["description"],
        price: fields["price"]
      }
    end
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
  # def search_similar(query, top_k = 5)
  #   cache_key = "search:#{query.downcase}"
  #   cached_results = @redis.get(cache_key)
  #   if cached_results
  #     # Retourne le cache parsé (symbolize_names pour avoir des symboles en clé)
  #     return JSON.parse(cached_results, symbolize_names: true)
  #   end

  #   # Générer l'embedding pour la recherche vectorielle
  #   query_embedding = generate_embedding(query)
  #   vector_blob = [query_embedding].flatten.pack("f*")

  #   query_str = "*=>[KNN #{top_k} @vector $vec AS vector_score]"
    
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
  #     fields_hash = Hash[*fields_array]
  #     lodgings << {
  #       key: key,
  #       title: fields_hash["title"],
  #       description: fields_hash["description"],
  #       price: fields_hash["price"]
  #     }
  #   end

  #   # Sauvegarder le résultat dans Redis avec TTL 30 secondes
  #   @redis.setex(cache_key, 30, lodgings.to_json)

  #   lodgings
  # end


  # Recherche vectorielle (commentée, à décommenter pour usage réel)
 def search_similar(query, top_k = 5)
  # Générer embedding pour la requête
  query_embedding = generate_embedding(query)
  vector_blob = query_embedding.pack("e*") # Float32

  # Requête RediSearch KNN
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





  # Incrémente la popularité
  def increment_popularity(lodging_key)
    @redis.zincrby("lodgings_popularity", 1, lodging_key)
  end

  # Retourne les top logements populaires
  def top_popular_lodgings(limit = 5)
  ids = @redis.zrevrange("lodgings_popularity", 0, limit - 1)
  lodgings = []
  
  ids.each do |key|
    data = @redis.hgetall(key) # ✅ On lit le hash directement
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

# db/seeds.rb
def generate_embedding(text)
  text = text.downcase
  embedding = Array.new(1536, 0.0)
  
  # Paris aura des valeurs fortes sur TOUTES les dimensions
  if text.include?("paris")
    embedding = Array.new(1536, 0.9) # Remplit tout à 0.9
  else
    # Autres villes avec valeurs faibles
    embedding = Array.new(1536, 0.1)
  end
  
  embedding
end


def broadcast(action, data)
  # Structure cohérente : { action: "created", lodging: { id: "...", title: "...", ... } }
  event = {
    "action" => action,
    "lodging" => data.transform_keys(&:to_s)
  }

  # Redis Streams (plat car Redis ne gère pas les objets imbriqués)
  flat_event = { "action" => action }.merge(event["lodging"])
  @redis.xadd("lodgings_stream", flat_event, id: "*")

  # Pub/Sub
  @redis.publish("lodgings_channel", event.to_json)

  # ActionCable
  ActionCable.server.broadcast("lodgings_channel", event)
end


end
