# Running the mill system on AWS (CloudFormation + EKS)

Status: written and checked offline only (cfn-lint, kustomize, kubeconform all pass). It has **not** been run in a real AWS account.

## What gets created
| Stack | File | Contents |
|---|---|---|
| network | `infra/aws/cloudformation/01-network.yaml` | VPC, 2 public + 2 private subnets, one NAT gateway |
| data | `02-data.yaml` | RDS MariaDB 10.11, two ElastiCache Redis (cache, queue), encrypted EFS for `sites`, ECR repo, generated passwords in Secrets Manager |
| eks | `03-eks.yaml` | EKS cluster, 2 x t3.large managed nodes, EFS CSI driver, IAM roles |

Kubernetes (`infra/aws/k8s/`): backend x2, frontend (nginx) x2, websocket, two queue workers, one scheduler, a setup Job (creates the site on first run, migrates on every deploy), and a Network Load Balancer with TLS from an ACM certificate.

## Use
1. Request an ACM certificate for your domain in the same region.
2. `cd infra/aws && ./validate.sh` (offline checks).
3. Dry run: `SITE_NAME=mill.example.com CERT_ARN=arn:aws:acm:... ./deploy.sh` prints the steps and creates nothing.
4. Real deploy: add `--apply`. Takes about 30 to 40 minutes the first time.
5. Point your domain's CNAME at the load balancer address the script prints. The Administrator password is in Secrets Manager.

## Cost (rough, Mumbai)
EKS this way is about $250 to $300 a month (control plane, 2 nodes, NAT, RDS, Redis, load balancer). One EC2 server running `docker/compose.prod.yml` is about $30 to $40. For one mill, the single server is the sensible start; EKS makes sense if you later run many sites.

## Things to check on first deploy
- Frappe v15 officially tests MariaDB 10.6. The RDS version is 10.11; verify the setup Job completes and the 55 backend tests pass against it, or change `EngineVersion` and parameter family.
- Redis here has no password or TLS, and is only reachable from inside the VPC.
- The load balancer sends plain HTTP to nginx after TLS ends at the NLB.
- Backups: RDS automated backups and a final snapshot on delete are on; EFS backup is on. Restore has not been rehearsed.

## Two separate environments on one small server each (recommended)
`infra/aws/single-server/server.yaml` is one self-contained environment. Deploy it twice (`./deploy.sh test ...` and `./deploy.sh prod ...`) and you get two copies that share nothing: own network and address range, own server, own fixed IP, own backup bucket, own generated admin password, own IAM role that can touch only its own bucket and secrets, own domain name.

| | test | prod |
|---|---|---|
| Server | t3.medium (4 GB) | t3.medium (4 GB) |
| Database | managed MariaDB 10.6 (RDS), db.t4g.small, 20 GB, 7 days of automatic backups | same |
| Region | Sydney ap-southeast-2 | Sydney ap-southeast-2 |
| Domain | e.g. mill-test.yourdomain | e.g. mill.yourdomain |
| Data | test data | real data |

Test and prod are identical on purpose. Rough cost per environment in Sydney: server about $39, database about $40, disk, fixed IP and secrets about $9, so about $85 a month each.

Region: this AWS account sits in an AWS Organization whose service control policy denies every region except Sydney (checked 2026-10-02: ap-south-1, ap-southeast-1 and us-east-1 are all denied). Use Sydney for both until that policy changes.

Database: the server runs the app, Redis and the web proxy; MariaDB runs in RDS in two private subnets, reachable only from that environment's server. RDS generates the master password and keeps it in Secrets Manager; the server reads it on first boot and writes `DB_HOST`, `DB_ROOT_USER` and `DB_ROOT_PASSWORD` to `docker/.env`, which switches on `docker/compose.rds.yml` (local db container off). The deploy user needs `AmazonRDSFullAccess`. Deleting a stack keeps a final database snapshot; prod also has deletion protection.

Notes
- Separate stacks in one AWS account is separate resources. For the strongest wall (separate billing and access) use two AWS accounts and a different `AWS_PROFILE` per environment; the same files work. Your $100 credit belongs to one account.
- The phone app for test must be built pointing at the test address, so test and prod APKs are different builds and a tester can never touch real data.
- No SSH port is open; log in through AWS Systems Manager Session Manager.
- Updating a running environment (new code or a fixed image): open the server in Session Manager, then `sudo -i`, `cd /opt/astrasun && bash docker/deploy.sh`. It pulls the branch, rebuilds the image, recreates the containers and migrates the site, and stops with an ERROR line if the India Compliance web script is missing. About 5 minutes, the site is down for about 2; the database (RDS) and uploaded files are untouched.
- When the phone says an order could not be saved: in Session Manager, `sudo -i`, `cd /opt/astrasun && git fetch origin <branch> && git reset --hard origin/<branch> && bash docker/try-order.sh`. It sends the same order the phone sends, as the administrator and as each Mill Sales, Mill Manager and Mill Owner user, saves nothing (every try is rolled back), and prints the server's own reason with the settings it depends on: company GST category, company addresses with a GSTIN, the item's HSN, warehouse and price, what the Mill Sales Role Profile brings, and for each user their mill jobs and whether ERPNext lets them create a Sales Order.
- The repository is private, so the server needs a read-only GitHub token stored in Secrets Manager (`GITHUB_TOKEN_SECRET_ARN`) until the code is moved to a public or deploy-key setup.
- Offline checks only so far (cfn-lint passes); never run in a real account.
