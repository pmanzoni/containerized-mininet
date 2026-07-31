# Mininet in a container

A Docker image for [Mininet](http://mininet.org/), based on
<https://github.com/iwaseyusuke/docker-mininet>.
It is a new version of [mininet-in-a-container](https://github.com/pmanzoni/mininet-in-a-container)

Works on Linux (e.g. Ubuntu, native or in VirtualBox) and on macOS (Intel and
Apple Silicon). The image is **multi-architecture**: Docker automatically pulls
the right variant (amd64 / arm64) for your machine, so there is a single tag and
no need to choose a CPU-specific one.

It adds to the base image:

* wireshark-qt
* wget
* python3-tk (for `miniedit.py`)
* git
* a `selftest.sh` self-diagnostic script

and clones the Mininet source code (pinned to a fixed release for
reproducibility): <https://github.com/mininet/mininet>

---

## Running the prebuilt image

The same command works on every platform. Docker selects amd64 or arm64
automatically.

### Linux

```bash
xhost +local:                      # allow the container to open X windows
docker run -it --rm --privileged -e DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /lib/modules:/lib/modules \
    --name mininet pmanzoni/containerized-mininet
```

### macOS (Intel or Apple Silicon)

Install and open **XQuartz** first. In XQuartz → Preferences → Security, enable
*"Allow connections from network clients"*.

```bash
xhost + 127.0.0.1
export DISPLAY=host.docker.internal:0
docker run -it --rm --privileged \
    --env="DISPLAY=host.docker.internal:0" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /lib/modules:/lib/modules \
    --name mininet pmanzoni/containerized-mininet
```

> **Note on `/lib/modules`:** this path only exists on Linux. On macOS the mount
> is harmless and simply ignored — Open vSwitch runs in user space inside the
> container.

---

## Starting Mininet

Once you are at the container prompt, how you start Mininet depends on the host:

**On Docker Desktop (macOS, or Windows/WSL, or Docker Desktop on Linux)** the
lightweight `linuxkit` kernel has no `openvswitch` kernel module, so switches
must use the **user-space datapath**. Use the provided wrapper:

```bash
mn-user           # = mn --switch ovsk,datapath=user --controller ovsc
mn-user -x        # same, opening xterm windows
```

**On native Linux** with the `openvswitch` module available, plain `mn` works:

```bash
mn -x
```

If plain `mn` hangs at `*** Starting 1 switches`, you are on a module-less
kernel — use `mn-user` instead.

---

## Checking your setup

Inside the container, run the self-diagnostic:

```bash
/selftest.sh
```

It verifies Open vSwitch (both daemons), Mininet, the required tools and the X
connection, and prints hints for anything that fails.

---

## Building the image yourself

### Local build (your architecture only)

```bash
docker build -t containerized-mininet .
```

### Multi-architecture build (amd64 + arm64)

Requires Docker Buildx (bundled with modern Docker):

```bash
docker buildx create --use --name mininetbuilder   # first time only
docker buildx build --platform linux/amd64,linux/arm64 \
    -t _DOCKER_USER_/containerized-mininet:latest --push .
```

The Mininet release is pinned via the `MININET_TAG` build argument in the
`Dockerfile`; change it there (or with `--build-arg MININET_TAG=...`) to use a
different version.

---

## Troubleshooting

Most container-side problems (Open vSwitch not starting, switches hanging) are
handled automatically now. The remaining issues are all **host-side** — things
the image cannot fix for you because they depend on your machine's X server.

**Using docker compose (either platform)**
```bash
# Linux:  xhost +local:
# macOS:  xhost + 127.0.0.1  &&  export DISPLAY=host.docker.internal:0
docker compose run --rm mininet
```

**`xhost: unable to open display` / `Can't open display`**
Grant access with `xhost` on the **host** (not inside the container), and set
`export DISPLAY=:0` (Linux) or `export DISPLAY=host.docker.internal:0` (macOS).
On macOS, do **not** also pass a bare `-e DISPLAY` in `docker run` — it injects
the Mac's launchd display path and breaks X. Use only
`--env="DISPLAY=host.docker.internal:0"`.

**macOS: `xrdb: Resource temporarily unavailable`**
In XQuartz → Preferences → Security either uncheck *"Authenticate connections"*,
or keep it checked and run `xhost + 127.0.0.1`.

**Linux: X windows still don't appear**
Try `xhost +` on the host and `export DISPLAY=host.docker.internal:0` inside the
container. On Linux prefer **Docker Engine (CE)** over Docker Desktop.

**`*** Error setting resource limits ...`**
Harmless; Mininet still works.