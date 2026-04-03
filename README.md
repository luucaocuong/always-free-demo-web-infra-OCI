# Aways free OCI Demo Web System — Terraform

Provisions a complete web stack on Oracle Cloud Infrastructure using Always Free resources.
This system will not incur any charges.

```
Internet
   │ port 80
   ▼
[Public Load Balancer]  ← 10.0.1.0/24 (public subnet)
   │ port 8080  (round-robin)
   ├──► [App Instance 1]  ─┐
   └──► [App Instance 2]  ─┤  10.0.2.0/24 (private app subnet)
                            │  Instance Pool (2 VMs, 2 ADs)
                            │ port 3306
                            ▼
                    [MySQL DB System]   10.0.3.0/24 (private DB subnet)
```

## Files

| File | Purpose |
|------|---------|
| `main.tf` | Provider, locals, ADs data source |
| `variables.tf` | All input variables |
| `network.tf` | VCN, IGW, NAT, route tables, security lists, subnets |
| `loadbalancer.tf` | Flexible LB, backend set, HTTP listener |
| `compute.tf` | Instance configuration + pool |
| `database.tf` | MySQL DB System |
| `cloud-init.sh` | Bootstrap: installs Node.js app, systemd service |
| `outputs.tf` | LB IP, MySQL hostname, pool ID |

## Quick Start

### 1. Prerequisites

```bash
# Install Terraform
brew install terraform        # macOS
# or download from https://developer.hashicorp.com/terraform/downloads

# Configure OCI CLI (creates ~/.oci/config and API key)
oci setup config
```

### 2. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your OCIDs, SSH key, etc.
```

Find your Oracle Linux 8 image OCID:
```bash
oci compute image list \
  --compartment-id <compartment_ocid> \
  --operating-system "Oracle Linux" \
  --operating-system-version "8" \
  --query 'data[0].id' --raw-output
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

After ~10 minutes, Terraform outputs the Load Balancer's public IP:

```
Outputs:
  load_balancer_public_ip = "132.x.x.x"
```

Open `http://132.x.x.x` in your browser to use the Items app.

## Application

The Node.js app (Express + mysql2) is installed via cloud-init and runs as a systemd service on port 8080.

### REST API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check (used by LB) |
| GET | `/items` | List all items |
| POST | `/items` | Create item `{ "name": "...", "description": "..." }` |
| DELETE | `/items/:id` | Delete item |

### MySQL Schema

```sql
CREATE TABLE items (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(255) NOT NULL,
  description TEXT,
  created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Teardown

```bash
terraform destroy
```

## Security Notes

- App instances have **no public IP** — reachable only via LB or Bastion
- MySQL accepts connections from the app subnet (10.0.2.0/24) only
- Store `terraform.tfvars` and `*.tfstate` securely — they contain secrets
- For production: add HTTPS (OCI Certificate + LB listener on 443), use OCI Vault for passwords, enable MySQL high-availability mode
