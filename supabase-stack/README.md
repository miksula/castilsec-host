# Supabase Local Development

This is demonstration of running Supabase locally in tandem with our [Castilsec App](https://github.com/miksula/castilsec-app.git).

See also [React Supabase Todolist demo](https://github.com/powersync-ja/powersync-js/tree/main/demos/react-supabase-todolist).

## Getting Started

Make sure you are using the latest version of the Supabase CLI. If you don't have the Supabase CLI installed, follow the [instructions](https://supabase.com/docs/guides/local-development/cli/getting-started#installing-the-supabase-cli). 

Start the Supabase project using the setup script (this automatically generates asymmetric signing keys):

```bash
chmod +x setup.sh
./setup.sh
```

Alternatively, you can run the steps manually:

```bash
supabase gen signing-key --algorithm ES256 --append

supabase start
```

Start the demonstration with `docker compose up`

> **Note:**  For git clone specifically, the clone layer is cached based on the command string, not the remote content. Using CACHE_BUST to force a fresh clone: 

```bash
# file: start-powersync.sh
docker compose build --build-arg CACHE_BUST=$(date +%s)
# invalidates cache fully
# docker compose build --no-cache
docker compose up 
# test server
# docker compose --env-file .env.test up --build
```

The frontend should be available at `http://localhost:8000`

> **Note:** This demo uses Supabase's new asymmetric JWT signing keys (ES256). PowerSync is compatible with these keys and will automatically fetch the public key from Supabase's JWKS endpoint. 

# Stop services

```bash
supabase stop
docker compose down
```