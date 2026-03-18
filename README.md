# PowerSync Self-Hosted Example

This is an example self-hosted project using the PowerSync Open Edition version of the [PowerSync Service](https://github.com/powersync-ja/powersync-service), which is published to Docker Hub as `journeyapps/powersync-service`.

This example uses Docker Compose to define and run the containers.

Learn more about self-hosting PowerSync [here](https://docs.powersync.com/self-hosting/getting-started).

### Storage

The [PowerSync Service](https://github.com/powersync-ja/powersync-service) uses MongoDB under the hood to store sync bucket state and operation history, regardless of whether you are syncing with a Postgres or MongoDB backend source database.

A basic MongoDB replica-set service is available in `ps-mongo.yaml`. The `powersync.yaml` config is configured to use this service by default. Different MongoDB servers can be configured by removing the `include` statement from `docker-compose.yaml` and updating `powersync.yaml`.

### Authentication

This example uses JWKS which provides the public key directly to the PowerSync instance in `powersync.yaml`'s `jwks` section.

The `key-generator` project demonstrates generating RSA key pairs for token signing.

### Sync Config

[Sync Configs](https://docs.powersync.com/usage/sync-rules) are currently defined by placing them in `./powersync/sync-config.yaml`.

# Cleanup

If you want to start from a fresh start:

- Delete the Docker volumes `mongo_storage` and `db_data`
  Their full names might vary depending on the directory where the `docker-compose` command was executed.
- Delete the service Docker containers.
