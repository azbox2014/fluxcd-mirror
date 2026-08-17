## Quick Start

```bash
# Pull
docker pull ghcr.io/azbox2014/zerotier-one:latest

# Run
docker run -d \
  --name zerotier-one \
  --device=/dev/net/tun \
  --cap-add=NET_ADMIN,SYS_ADMIN,NET_RAW \
  -v /var/lib/zerotier-one:/var/lib/zerotier-one \
  ghcr.io/azbox2014/zerotier-one:latest
```


