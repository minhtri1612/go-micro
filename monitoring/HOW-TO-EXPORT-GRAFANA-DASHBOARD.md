# 📋 How to Export Grafana Dashboard as ConfigMap

## Step 1: Export Dashboard JSON from Grafana UI

1. **Open your dashboard in Grafana**
   - Go to your dashboard

2. **Open Dashboard Settings**
   - Click the **gear icon** (⚙️) in the top right
   - OR click the dashboard dropdown menu → "Dashboard settings"

3. **Copy JSON Model**
   - Click on **"JSON Model"** tab (left sidebar)
   - Click **"Copy JSON to clipboard"** button
   - OR select all (Ctrl+A) and copy (Ctrl+C)

4. **Save the JSON** (temporarily)
   - Paste it somewhere (text editor) to verify it's copied

## Step 2: Create ConfigMap with Dashboard JSON

### Create ConfigMap YAML file:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    grafana_dashboard: "1"  # <-- This label tells Grafana to auto-load it
  name: go-microservices-dashboard
  namespace: monitoring  # <-- Must be in monitoring namespace (where Grafana is)
data:
  # The filename will be the dashboard name in Grafana
  go-microservices.json: |-
    {
      # Paste your copied JSON here
      "dashboard": {
        ...
      }
    }
```

## Step 3: Apply the ConfigMap

```bash
kubectl apply -f k8s/grafana-dashboard-microservices.yaml
```

## Step 4: Verify in Grafana

1. Go to Grafana → Dashboards
2. Look for your dashboard (should auto-appear!)
3. If not, go to Dashboards → Import → and it should be available

## Quick Tips

- **Label is critical**: `grafana_dashboard: "1"` must be set
- **Namespace**: Must be `monitoring` (where Grafana runs)
- **Filename**: The key in `data:` section becomes the dashboard name
- **Grafana will auto-reload**: Changes appear within ~30 seconds


