# Mininet in a container
#
# Imagen multi-arquitectura (amd64 / arm64). Docker elige automáticamente
# la variante correcta según el host, por lo que NO hace falta un tag de CPU.
#
# Build multi-arch (requiere buildx):
#   docker buildx create --use --name mininetbuilder   # solo la primera vez
#   docker buildx build --platform linux/amd64,linux/arm64 \
#       -t pmanzoni/containerized-mininet:latest --push .
#
# Build local (solo tu arquitectura):
#   docker build -t containerized-mininet .

FROM ubuntu:22.04

LABEL org.opencontainers.image.title="containerized-mininet" \
      org.opencontainers.image.description="Mininet + Open vSwitch + Wireshark para prácticas de SDN" \
      org.opencontainers.image.source="https://github.com/pmanzoni/containerized-mininet" \
      org.opencontainers.image.licenses="Apache-2.0"

USER root
WORKDIR /root

# Evita prompts interactivos de apt (tzdata, etc.) durante el build
ENV DEBIAN_FRONTEND=noninteractive

# Versión de Mininet fijada para que TODOS los alumnos tengan lo mismo.
# Tags disponibles: https://github.com/mininet/mininet/tags
#   2.3.0    -> última release ESTABLE (recomendada para clase)
#   2.3.1b4  -> última beta (más reciente, pero beta)
ARG MININET_TAG=2.3.0

COPY ENTRYPOINT.sh /
COPY selftest.sh /
COPY mn-user /usr/local/bin/mn-user
COPY .Xresources /root/

# Todo en una sola capa: un único apt-get update, instalación y limpieza.
# Esto reduce tamaño y evita que builds en fechas distintas cojan versiones distintas.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        iproute2 \
        iputils-ping \
        mininet \
        net-tools \
        openvswitch-switch \
        openvswitch-testcontroller \
        python3-tk \
        tcpdump \
        vim \
        wget \
        wireshark-qt \
        x11-xserver-utils \
        xterm \
    && rm -rf /var/lib/apt/lists/* \
    && chmod +x /ENTRYPOINT.sh /selftest.sh /usr/local/bin/mn-user

# Código fuente de Mininet fijado a un tag concreto (build reproducible)
RUN git clone --branch "${MININET_TAG}" --depth 1 \
        https://github.com/mininet/mininet.git /root/mininet

# miniedit.py parcheado (cambio 2023)
COPY miniedit.py /root/mininet/examples/miniedit.py

# Enlace simbólico para el controlador de referencia
RUN ln -sf /usr/bin/ovs-testcontroller /usr/bin/controller

EXPOSE 6633 6653 6640

ENTRYPOINT ["/ENTRYPOINT.sh"]
