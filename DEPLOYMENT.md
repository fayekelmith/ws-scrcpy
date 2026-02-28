# ws-scrcpy Deployment Guide

This guide covers deploying the simplified ws-scrcpy fork for iframe embedding in Hive platform.

## Repository

**Your fork:** https://github.com/fayekelmith/ws-scrcpy  
**Branch:** `feat/customize-browser`

## Key Changes from Original

1. **Clean URL auto-connect** - No query parameters needed
2. **Runtime environment variables** - Device configured at runtime, not build time
3. **Node 24** - Upgraded from Node 18
4. **Simplified UI** - Pixel 9 frame with side controls
5. **MSE decoder only** - Removed Broadway/TinyH264/WebCodecs

---

## Option 1: Docker Compose (Recommended for Testing)

### Quick Start

```bash
# Clone your fork
git clone https://github.com/fayekelmith/ws-scrcpy.git
cd ws-scrcpy
git checkout feat/customize-browser

# Start redroid + ws-scrcpy
docker compose -f docker-compose.redroid.yml up -d

# Check logs
docker compose -f docker-compose.redroid.yml logs -f ws-scrcpy

# Access web UI
open http://localhost:8000
```

### Architecture

```
Browser (iframe) → ws-scrcpy:8000 → redroid:5555 (ADB) → redroid:8886 (scrcpy)
                        ↓
                  android-net (Docker network)
```

### Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `SCRCPY_DEVICE_HOST` | Device hostname/IP:port for ADB | *required* | `redroid:5555` |
| `SCRCPY_DEVICE_PORT` | scrcpy WebSocket server port | `8886` | `8886` |
| `WS_SCRCPY_SERVER_PORT` | ws-scrcpy HTTP server port | `8000` | `8000` |
| `NODE_ENV` | Node environment | `production` | `production` |

### Configuration

Edit `docker-compose.redroid.yml`:

```yaml
environment:
  - SCRCPY_DEVICE_HOST=redroid:5555
  - SCRCPY_DEVICE_PORT=8886
```

### Cleanup

```bash
docker compose -f docker-compose.redroid.yml down -v
```

---

## Option 2: Kubernetes/Hive Platform

### Prerequisites

- Kubernetes cluster with redroid pods
- Each ws-scrcpy instance maps to one redroid container
- Network policy allows pod-to-pod communication

### Deployment YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ws-scrcpy
  namespace: hive
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ws-scrcpy
  template:
    metadata:
      labels:
        app: ws-scrcpy
    spec:
      containers:
      - name: ws-scrcpy
        image: fayekelmith/ws-scrcpy:latest
        ports:
        - containerPort: 8000
          name: http
        env:
        # Point to redroid service in same namespace
        - name: SCRCPY_DEVICE_HOST
          value: "redroid-service.hive.svc.cluster.local:5555"
        - name: SCRCPY_DEVICE_PORT
          value: "8886"
        - name: NODE_ENV
          value: "production"
        command:
        - sh
        - -c
        - |
          adb connect $SCRCPY_DEVICE_HOST
          adb wait-for-device
          npm start
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: ws-scrcpy-service
  namespace: hive
spec:
  selector:
    app: ws-scrcpy
  ports:
  - port: 8000
    targetPort: 8000
    name: http
  type: ClusterIP
```

### Ingress for Iframe Embedding

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ws-scrcpy-ingress
  namespace: hive
  annotations:
    nginx.ingress.kubernetes.io/websocket-services: "ws-scrcpy-service"
spec:
  rules:
  - host: android.hive.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ws-scrcpy-service
            port:
              number: 8000
```

### Iframe Integration

```html
<!-- Hive platform iframe -->
<iframe 
  src="https://android.hive.example.com" 
  width="100%" 
  height="100%" 
  frameborder="0"
  allow="clipboard-write"
></iframe>
```

**That's it!** No query parameters needed. Each ws-scrcpy instance auto-connects to its configured device.

---

## Option 3: Building Custom Image

### For Devcontainers

Update your Dockerfile (see `devcontainer.Dockerfile`):

```dockerfile
# ws-scrcpy with Node 24 and your customizations
RUN bash -c "source /usr/local/share/nvm/nvm.sh \
    && nvm install 24 \
    && nvm use 24 \
    && git clone https://github.com/fayekelmith/ws-scrcpy /opt/ws-scrcpy \
    && cd /opt/ws-scrcpy \
    && git checkout feat/customize-browser \
    && npm install \
    && npm run dist"
```

### For Production

```bash
# Build image
docker build -t fayekelmith/ws-scrcpy:latest .

# Push to registry
docker push fayekelmith/ws-scrcpy:latest

# Run with environment variables
docker run -d \
  -p 8000:8000 \
  -e SCRCPY_DEVICE_HOST=redroid:5555 \
  fayekelmith/ws-scrcpy:latest
```

---

## Troubleshooting

### Device Not Connecting

```bash
# Check ADB connection
docker exec ws-scrcpy adb devices

# Manually connect
docker exec ws-scrcpy adb connect redroid:5555

# Check scrcpy server is running on device
docker exec redroid ps aux | grep scrcpy
```

### WebSocket Errors

- Ensure `SCRCPY_DEVICE_HOST` includes port (e.g., `redroid:5555`)
- Check network connectivity between containers
- Verify scrcpy server is on port 8886 (default)

### Build Errors

```bash
# Clean build
npm run clean
npm install
npm run dist

# Check Node version (must be 24)
node --version  # Should show v24.x.x
```

### Black Screen

- Controls should appear on hover (right side of frame)
- Check browser console for errors
- Verify video codec support (H264 MSE required)

---

## Local Development

```bash
# Start local emulator
~/Library/Android/sdk/emulator/emulator -avd Pixel_7 -no-window -no-audio

# Set device and build
export SCRCPY_DEVICE_HOST=emulator-5554
npm run dist

# Start server
cd dist && npm start

# Open browser
open http://localhost:8000
```

---

## Next Steps

1. **Test locally** with emulator using docker-compose
2. **Build production image** and push to your registry
3. **Deploy to Hive** with Kubernetes manifests
4. **Configure ingress** for iframe embedding
5. **Monitor logs** and performance

## Support

For issues specific to this fork:
- GitHub: https://github.com/fayekelmith/ws-scrcpy/issues
- Branch: `feat/customize-browser`

For original ws-scrcpy issues:
- GitHub: https://github.com/NetrisTV/ws-scrcpy
