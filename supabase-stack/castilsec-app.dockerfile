FROM denoland/deno:ubuntu

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

ARG VITE_SUPABASE_URL=
ARG SUPABASE_PUBLISHABLE_KEY=
ARG VITE_POWERSYNC_URL=

ENV VITE_SUPABASE_ANON_KEY=${SUPABASE_PUBLISHABLE_KEY}

# Shallow clone — only fetches the latest commit, much faster
ARG CACHE_BUST=1
RUN git clone --depth 1 https://github.com/miksula/castilsec-app.git

WORKDIR /castilsec-app

# Cache the Deno module downloads across rebuilds
RUN --mount=type=cache,target=/root/.cache/deno deno install

# Build the app
RUN --mount=type=cache,target=/root/.cache/deno deno task build

# Copy startup script that runs both processes
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 4170 8001

CMD ["/start.sh"]
