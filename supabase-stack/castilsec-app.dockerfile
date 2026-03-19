FROM denoland/deno:ubuntu

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

ARG VITE_SUPABASE_URL=
ARG SUPABASE_PUBLISHABLE_KEY=
ARG VITE_POWERSYNC_URL=

ENV VITE_SUPABASE_ANON_KEY=${SUPABASE_PUBLISHABLE_KEY}

ARG CACHE_BUST=1
RUN git clone https://github.com/miksula/castilsec-app.git

# Set the working directory inside the container
WORKDIR  /castilsec-app

# Install dependencies and setup the monorepo
RUN deno install

# Build the app
RUN deno task build

# Start the api
RUN deno run --allow-net --allow-read apps/api/index.ts

# Start hosting
CMD ["deno", "run", "--allow-net", "--allow-read", "file-server.ts"]
