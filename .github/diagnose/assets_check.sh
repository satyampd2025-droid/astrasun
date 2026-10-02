# Prints what a container sees of the built web assets (run inside the image or a running container).
cd /home/frappe/frappe-bench
echo "-- sites/assets (first entries)"
ls -la sites/assets | head -25
echo "-- assets.json keys that mention india or astrasun"
env/bin/python - <<'PY'
import json
d = json.load(open("sites/assets/assets.json"))
print("total keys:", len(d))
for k, v in d.items():
    if "india" in k or "astrasun" in k:
        print(" ", k, "->", v)
PY
echo "-- built files inside the app"
ls apps/india_compliance/india_compliance/public/dist/js 2>&1 | head -5
echo "-- mounts under the bench"
grep " /home/frappe/frappe-bench" /proc/mounts | cut -d' ' -f1-3 | head
