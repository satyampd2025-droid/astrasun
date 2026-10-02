# Running the mill system

One Docker stack: ERPNext v15 + India Compliance + our `astrasun` app, with MariaDB and Redis.
The same files run on a laptop and on the Mumbai VPS.

## First start
```bash
docker build -f docker/Dockerfile -t astrasun:dev .   # from the repo root
cp docker/.env.example docker/.env                     # then change the passwords
cd docker && docker compose up -d
```
Wait until `docker compose ps -a` shows `create-site` exited with 0, then open http://localhost:8080,
log in as `Administrator` with `ADMIN_PASSWORD`, and finish the setup wizard (country India, company name).
Finishing the wizard creates the mill masters: warehouses, wheat, flour, packed SKUs, bags and BOMs.

## After changing the app
```bash
docker build -f docker/Dockerfile -t astrasun:dev . && cd docker && docker compose up -d
docker compose exec backend bench --site mill.localhost migrate
```

## Tests
```bash
docker compose exec backend bench --site mill.localhost set-config allow_tests true
docker compose exec backend bench --site mill.localhost run-tests --app astrasun
```
