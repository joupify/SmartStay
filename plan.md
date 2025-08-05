✅ PLAN.md
SmartStay AI – Plan & Journal de Développement
🎯 Objectif
Créer une application web qui recommande des logements en temps réel, en utilisant Redis comme base principale et IA pour la recherche vectorielle.

📌 Fonctionnalités principales
Stockage Redis JSON
→ Tous les logements sont stockés dans Redis (pas de PostgreSQL).

Recherche vectorielle IA (Redis Vector Search)
→ Trouver les logements similaires avec OpenAI embeddings.

Recherche textuelle & filtres (RediSearch)

Notifications live (Pub/Sub + ActionCable)

Statistiques temps réel (Redis Streams)

Assistant IA avec Semantic Cache

🛠 Stack technique
Backend : Ruby on Rails 8 (API + Hotwire)

IA : OpenAI (embeddings + assistant)

Redis Stack :

Redis JSON

Redis Search

Redis Vector Search

Redis Streams

Redis Pub/Sub

Front : Hotwire + Tailwind CSS

📂 Structure projet

smartstay-ai/
│
├── app/
│ ├── controllers/lodgings_controller.rb
│ ├── services/redis_lodging_service.rb
│ ├── channels/lodgings_channel.rb
│ └── views/lodgings/index.html.erb
├── config/initializers/redis.rb
├── PLAN.md
├── README.md
└── ...
