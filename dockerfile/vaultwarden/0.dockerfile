# syntax=docker/dockerfile:1

# This file was generated using a Jinja2 template.
# Please make your changes in `Dockerfile.j2` and then `make` the individual Dockerfiles.

# Using multistage build:
#  https://docs.docker.com/develop/develop-images/multistage-build/
#  https://whitfin.io/speeding-up-rust-docker-builds/
####################### VAULT BUILD IMAGE  #######################
# The web-vault digest specifies a particular web-vault build on Docker Hub.
# Using the digest instead of the tag name provides better security,
# as the digest of an image is immutable, whereas a tag name can later
# be changed to point to a malicious image.
#
# To verify the current digest for a given tag name:
# - From https://hub.docker.com/r/vaultwarden/web-vault/tags,
#   click the tag name to view the digest of the image it currently points to.
# - From the command line:
#     $ docker pull vaultwarden/web-vault:v2022.05.0
#     $ docker image inspect --format "{{.RepoDigests}}" vaultwarden/web-vault:v2022.05.0
#     [vaultwarden/web-vault@sha256:7b07588398cf89488a1bfc7a5b75aa5877612674578bdedc098f1bc78555703f]
#
# - Conversely, to get the tag name from the digest:
#     $ docker image inspect --format "{{.RepoTags}}" vaultwarden/web-vault@sha256:7b07588398cf89488a1bfc7a5b75aa5877612674578bdedc098f1bc78555703f
#     [vaultwarden/web-vault:v2022.05.0]
#
FROM vaultwarden/web-vault@sha256:7b07588398cf89488a1bfc7a5b75aa5877612674578bdedc098f1bc78555703f as vault

########################## BUILD IMAGE  ##########################
FROM rust:1.61-bullseye as build



# Build time options to avoid dpkg warnings and help with reproducible builds.
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TZ=UTC \
    TERM=xterm-256color \
    CARGO_HOME="/root/.cargo" \
    USER="root"


# Create CARGO_HOME folder and don't download rust docs
RUN mkdir -pv "${CARGO_HOME}" \
    && rustup set profile minimal

#
# Install required build libs for armel architecture.
# hadolint ignore=DL3059
RUN dpkg --add-architecture armel \
    && apt-get update \
    && apt-get install -y \
        --no-install-recommends \
        libssl-dev:armel \
        libc6-dev:armel \
        libpq5:armel \
        libpq-dev:armel \
        libmariadb3:armel \
        libmariadb-dev:armel \
        libmariadb-dev-compat:armel \
        gcc-arm-linux-gnueabi \
    #
    # Make sure cargo has the right target config
    && echo '[target.arm-unknown-linux-gnueabi]' >> "${CARGO_HOME}/config" \
    && echo 'linker = "arm-linux-gnueabi-gcc"' >> "${CARGO_HOME}/config" \
    && echo 'rustflags = ["-L/usr/lib/arm-linux-gnueabi"]' >> "${CARGO_HOME}/config"

# Set arm specific environment values
ENV CC_arm_unknown_linux_gnueabi="/usr/bin/arm-linux-gnueabi-gcc" \
    CROSS_COMPILE="1" \
    OPENSSL_INCLUDE_DIR="/usr/include/arm-linux-gnueabi" \
    OPENSSL_LIB_DIR="/usr/lib/arm-linux-gnueabi"


# Creates a dummy project used to grab dependencies
RUN USER=root cargo new --bin /app
WORKDIR /app

# Copies over *only* your manifests and build files
COPY ./Cargo.* ./
COPY ./rust-toolchain ./rust-toolchain
COPY ./build.rs ./build.rs

RUN rustup target add arm-unknown-linux-gnueabi

# Configure the DB ARG as late as possible to not invalidate the cached layers above
ARG DB=sqlite,mysql,postgresql

# Builds your dependencies and removes the
# dummy project, except the target folder
# This folder contains the compiled dependencies
RUN cargo build --features ${DB} --release --target=arm-unknown-linux-gnueabi \
    && find . -not -path "./target*" -delete

# Copies the complete project
# To avoid copying unneeded files, use .dockerignore
COPY . .

# Make sure that we actually build the project
RUN touch src/main.rs

# Builds again, this time it'll just be
# your actual source files being built
# hadolint ignore=DL3059
RUN cargo build --features ${DB} --release --target=arm-unknown-linux-gnueabi

# Create a special empty file which we check within the application.
# If this file exists, then we exit Vaultwarden to prevent data loss when someone forgets to use volumes.
# If you really really want to use volatile storage you can set the env `I_REALLY_WANT_VOLATILE_STORAGE=true`
# This file should disappear if a volume is mounted on-top of this using a docker volume.
# We run this in the build image and copy it over, because the runtime image could be missing some executables.
# hadolint ignore=DL3059
RUN touch /vaultwarden_docker_persistent_volume_check

######################## RUNTIME IMAGE  ########################
# Create a new stage with a minimal image
# because we already have a binary built
FROM balenalib/rpi-debian:bullseye

ENV ROCKET_PROFILE="release" \
    ROCKET_ADDRESS=0.0.0.0 \
    ROCKET_PORT=80

# hadolint ignore=DL3059
RUN [ "cross-build-start" ]

# Create data folder and Install needed libraries
RUN mkdir /data \
    && apt-get update && apt-get install -y \
    --no-install-recommends \
    openssl \
    ca-certificates \
    curl \
    dumb-init \
    libmariadb-dev-compat \
    libpq5 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# In the Balena Bullseye images for armv6/rpi-debian there is a missing symlink.
# This symlink was there in the buster images, and for some reason this is needed.
# hadolint ignore=DL3059
RUN ln -v -s /lib/ld-linux-armhf.so.3 /lib/ld-linux.so.3

# hadolint ignore=DL3059
RUN [ "cross-build-end" ]

VOLUME /data
EXPOSE 80
EXPOSE 3012

# Copies the files from the context (Rocket.toml file and web-vault)
# and the binary from the "build" stage to the current stage
WORKDIR /
COPY --from=vault /web-vault ./web-vault
COPY --from=build /vaultwarden_docker_persistent_volume_check /data/vaultwarden_docker_persistent_volume_check
COPY --from=build /app/target/arm-unknown-linux-gnueabi/release/vaultwarden .

COPY docker/healthcheck.sh /healthcheck.sh
COPY docker/start.sh /start.sh

HEALTHCHECK --interval=60s --timeout=10s CMD ["/healthcheck.sh"]

# Configures the startup!
# We should be able to remove the dumb-init now with Rocket 0.5
# But the balenalib images have some issues with there entry.sh
# See: https://github.com/balena-io-library/base-images/issues/735
# Lets keep using dumb-init for now, since that is working fine.
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["/start.sh"]
