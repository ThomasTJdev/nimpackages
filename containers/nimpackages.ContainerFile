FROM docker.io/library/ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive

RUN groupadd nimgroup \
    && useradd -m nimmer -d /home/nimmer -s /bin/bash \
    && usermod -a -G nimgroup,sudo nimmer \
    && mkdir -p /home/nimmer/config \
    && mkdir -p /home/nimmer/public-dist \
    && mkdir -p /home/nimmer/storage \
    && chown -R nimmer:nimgroup /home/nimmer \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      libpq-dev \
      libpcre3-dev

WORKDIR /home/nimmer

COPY src/nimpackages /home/nimmer/nimpackages

CMD ["/home/nimmer/nimpackages"]


#podman build -f containers/nimpackages.ContainerFile . -t nimpackages
#podman tag nimpackages <repo>/nimpackages:latest
#podman push <repo>/nimpackages:latest
