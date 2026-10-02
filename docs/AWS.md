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
