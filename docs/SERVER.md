# Mill server: what it is and how to set it up

The phone app and the office web screens both talk to one server running ERPNext + our `astrasun` app (see [ARCHITECTURE.md](ARCHITECTURE.md), decision D3). It holds the data for stock, orders, invoices and payments.

## Does it need AWS?
No. Any Linux server in India works. Same software, same setup script.

| Option | About | Notes |
|---|---|---|
| AWS Lightsail, Mumbai | ₹1,500-2,500 a month for 4 GB | Simple fixed price, good if you already use AWS |
| DigitalOcean, Bangalore | similar | Simple, good support |
| E2E Networks / other Indian hosts | often cheaper | Fine, slightly less polished |

Needs: Ubuntu 24.04, 4 GB RAM, 2 CPUs, 80 GB disk, a public IP, and a web address (for example `mill.atulyaa.in`) pointing to it.

## Setup (once, about 15 minutes)
1. Create the server, and point the web address at its IP.
2. Log in to it as root and run the line in the header of `docker/server-setup.sh` with your address and a password you choose.
3. Open `https://<address>`, log in as `Administrator`.

It installs everything, gets the HTTPS certificate, and sets up a nightly backup (kept 14 days).

## Updating
Run `docker/deploy.sh` on the server, or use the **Deploy to server** button in GitHub Actions after adding three repository secrets: `SERVER_HOST`, `SERVER_USER`, `SERVER_SSH_KEY`.

## Connecting the phone app
Set the repository variable `MILL_SERVER_URL` to `https://<address>`. The next app build then logs in to this server.
