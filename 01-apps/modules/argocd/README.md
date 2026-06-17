# ArgoCD

## Login

### 1. Get the initial admin password

```sh
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Login via CLI

```sh
argocd login 192.168.20.222 --insecure --username admin --password <password-from-step-1>
```

### 3. (Optional) Change the admin password

```sh
argocd account update-password
```

### 4. Web UI

Open <http://192.168.20.222> in a browser and sign in with `admin` and the password from step 1.
