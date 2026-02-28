# Docker Setup Guide

Quick guide for running ws-scrcpy with redroid using Docker Compose.

## Quick Start

```bash
# 1. Copy environment template
cp .env.docker .env

# 2. (Optional) Adjust settings in .env
nano .env

# 3. Start services
docker compose -f docker-compose.redroid.yml up -d

# 4. Check logs
docker compose -f docker-compose.redroid.yml logs -f

# 5. Access web interface
open http://localhost:8000
```

## Configuration

### Environment Variables (.env file)

```bash
# Redroid settings
REDROID_VERSION=latest          # Redroid image version
ADB_PORT=5555                   # ADB server port
ANDROID_WIDTH=1080              # Screen width
ANDROID_HEIGHT=2340             # Screen height (Pixel 9: 19.5:9 ratio)
ANDROID_DPI=420                 # Screen density
ANDROID_FPS=60                  # Frame rate

# ws-scrcpy settings
SCRCPY_PORT=8000                # Web UI port
BOOT_WAIT=10                    # Seconds to wait for redroid boot
```

### Runtime Configuration

The ws-scrcpy service is configured via environment variables in `docker-compose.redroid.yml`:

```yaml
environment:
  - SCRCPY_DEVICE_HOST=redroid:5555  # Device to connect to
  - SCRCPY_DEVICE_PORT=8886          # scrcpy server port
```

### Volumes

- **redroid-data**: Persists Android system data across restarts
- **adb-keys**: Persists ADB authentication keys (no re-pairing needed)

## Usage

### Start Services

```bash
docker compose -f docker-compose.redroid.yml up -d
```

### Stop Services

```bash
docker compose -f docker-compose.redroid.yml down
```

### Complete Reset (deletes all data)

```bash
docker compose -f docker-compose.redroid.yml down -v
```

### View Logs

```bash
# All services
docker compose -f docker-compose.redroid.yml logs -f

# Specific service
docker compose -f docker-compose.redroid.yml logs -f ws-scrcpy
docker compose -f docker-compose.redroid.yml logs -f redroid
```

### Check Status

```bash
docker compose -f docker-compose.redroid.yml ps
```

### Connect ADB Manually

```bash
# From host
adb connect localhost:5555
adb devices

# From ws-scrcpy container
docker exec ws-scrcpy adb devices
```

## Troubleshooting

### Redroid won't start

```bash
# Check if KVM is available (Linux only)
ls -la /dev/kvm

# Check logs
docker compose -f docker-compose.redroid.yml logs redroid
```

### ADB connection failed

```bash
# Restart ADB server in ws-scrcpy
docker exec ws-scrcpy adb kill-server
docker exec ws-scrcpy adb start-server
docker exec ws-scrcpy adb connect redroid:5555

# Check network connectivity
docker exec ws-scrcpy ping redroid
```

### Black screen in browser

1. Check browser console for errors
2. Verify H264 MSE decoder support
3. Check scrcpy server is running:
   ```bash
   docker exec redroid ps aux | grep scrcpy
   ```

### Controls not showing

- Hover over the phone frame (right side)
- Controls auto-hide when not hovering
- Check browser console for JavaScript errors

## Architecture

```
Browser → http://localhost:8000 → ws-scrcpy:8000
                                       ↓
                                   (android-net)
                                       ↓
                                  redroid:5555 (ADB)
                                  redroid:8886 (scrcpy)
```

## Customization

### Change Screen Resolution

Edit `.env`:
```bash
ANDROID_WIDTH=1440
ANDROID_HEIGHT=3120
ANDROID_DPI=560
```

Then restart:
```bash
docker compose -f docker-compose.redroid.yml up -d --force-recreate redroid
```

### Change Web Port

Edit `.env`:
```bash
SCRCPY_PORT=9000
```

Access at: http://localhost:9000

### Multiple Redroid Instances

Create separate compose files or use profiles:

```yaml
# docker-compose.multi.yml
services:
  redroid-1:
    image: redroid/redroid:latest
    # ... config ...
    
  ws-scrcpy-1:
    environment:
      - SCRCPY_DEVICE_HOST=redroid-1:5555
    ports:
      - "8001:8000"
```

## Production Deployment

For production with Kubernetes, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Support

- Fork: https://github.com/fayekelmith/ws-scrcpy
- Branch: `feat/customize-browser`
- Original: https://github.com/NetrisTV/ws-scrcpy
