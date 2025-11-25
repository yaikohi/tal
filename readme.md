# Talos Proxmox Terraform Talhelper GitOps setup

## Setup talos configuration 

> uses `sops`, `age`, and `talhelper`

### Create a talconfig.yaml and configure to however you need.

> Check talconfig.example.yaml.

```bash
touch talconfig.yaml
```

```bash
export CLUSTER_NAME="yaya"
```

### Create secrets

```bash
talhelper gensecret > talsecret.sops.yaml
```

### Generate key-pair

```bash
age-keygen -o key.txt
```

### Add public key to `.sops.yaml` 

```yaml
creation_rules:
  - path_regex: .*\.sops\.yaml$
    key_groups:
      - age:
        - "age1..." # <-- Your PUBLIC key goes here

```

### Encrypt the secrets

```bash
sops --encrypt --in-place talsecret.sops.yaml
```

### Unlock for usage

```bash
export SOPS_AGE_KEY_FILE=$(pwd)/key.txt
```

### Generate the configuration for the talos cluster

```bash
talhelper genconfig
```


## commands

### To add nodes
- Add them to `talconfig.yaml`
- regenerate config `talhelper genconfig`
- run `tofu apply` .

### To upgrade Talos 
- Change version in `talconfig.yaml`, 
- regenerate `talhelper genconfig`
- `tofu apply`

### To destroy: 
- `tofu destroy`