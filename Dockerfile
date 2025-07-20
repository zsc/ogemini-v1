# OGemini Docker Environment
# Based on official OCaml/opam image with minimal Debian 12 (no desktop) and OCaml 5.4
FROM ocaml/opam:debian-12-ocaml-5.1

# Switch to root for system package installation
USER root

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Build essentials
    build-essential \
    git \
    curl \
    wget \
    libcurl4-openssl-dev \
    rlwrap \
    vim \
    nano \
    tree \
    htop \
    bash \
    coreutils \
    findutils \
    grep \
    sed \
    gawk \
    && rm -rf /var/lib/apt/lists/*

# Switch back to opam user
USER opam

# Set up opam environment
RUN eval $(opam env) && \
    opam repository remove beta || true && \
    opam update && \
    opam install -y \
        dune \
        lwt \
        yojson \
        re \
        ocamlformat

# Create workspace directory
USER root
RUN mkdir -p /workspace && \
    chown -R opam:opam /workspace

# Switch to opam user for running
USER opam
WORKDIR /workspace

# Set up environment
ENV PATH="/home/opam/.opam/5.1/bin:${PATH}"
ENV OPAMYES="1"

# Copy entrypoint script
COPY --chown=opam:opam scripts/docker-entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Default command - can be overridden
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
