docker compose build --build-arg CACHE_BUST=$(date +%s)

# invalidates cache fully
# docker compose build --no-cache

docker compose up 

# test server
# docker compose --env-file .env.test up --build