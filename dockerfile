FROM ocaml/opam:ubuntu-22.04 AS build-deps

USER root

# Install only essential system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libffi-dev \
    libssl-dev \
    libev-dev \
    libgmp-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Initialize opam with compiler cache
RUN opam init -a --disable-sandboxing && \
    opam switch create 5.2.0 && \
    eval $(opam env)

WORKDIR /app

# First install core dependencies that rarely change
RUN opam install -y \
    dune \
    core \
    core_unix \
    ppx_jane \
    && opam clean -a -c -s --logs

# Copy dependency files individually and install them in separate layers
COPY --chown=opam:opam dune-project ./
COPY --chown=opam:opam finance_sim.opam ./
COPY --chown=opam:opam lib/ ./lib/

# Install direct dependencies from the opam file
RUN opam install . --deps-only --yes --locked --ignore-constraints-on dune,core,core_unix,ppx_jane && \
    opam clean -a -c -s --logs

# Build stage
FROM build-deps AS builder

# Copy the rest of the source code
COPY --chown=opam:opam . .

# Build the project without -p flag to use local libraries
RUN eval $(opam env) && \
    dune build @install --profile release

# Final stage remains the same
FROM ubuntu:22.04 AS release

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libffi7 \
    libssl3 \
    libev-dev \
    libgmp-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/_build/default/bin/main.exe /usr/local/bin/finance_sim

COPY test.html test.html

ENTRYPOINT ["/usr/local/bin/finance_sim"]
CMD ["serve"]


##########################
########################
# Old docker setup for just patching the executable
########################
# FROM ubuntu:noble
#
# # Install patchelf
# RUN apt-get update && apt-get install -y patchelf
#
# WORKDIR /app
# COPY dist/finance_sim /app/finance_sim
#
# # Patch the binary
# RUN patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 /app/finance_sim && \
#     deps=$(ldd /app/finance_sim | grep "=>" | awk '{print $3}') && \
#     rpath="" && \
#     for dep in $deps; do \
#         dir=$(dirname "$dep"); \
#         rpath="$rpath:$dir"; \
#     done && \
#     rpath=${rpath#:} && \
#     patchelf --set-rpath "$rpath" /app/finance_sim
#
# CMD ["/app/finance_sim", "serve"]

