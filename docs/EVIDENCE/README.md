# EVIDENCE

Drop screenshots/logs here, named so a grader knows what each proves:

- `nodes-ready.png` — multi-node `kubectl get nodes`
- `pods-spread.png` — replicas on different nodes (`-o wide`)
- `tls-valid.png` — valid cert (curl -vI / SSL Labs)
- `pvc-persist.log` — data survives a Pod kill
- `zero-downtime.log` — unbroken 200s during a rollout
- `hpa-scale.png` — replicas climbing under load
- `argocd-synced.png` — Argo CD Synced + Healthy
- `failover.png` — app up after a node drain

  
<img width="810" height="544" alt="kubectl get pods -n argocd" src="https://github.com/user-attachments/assets/b72e57f0-c106-47cc-b968-8bcb540124a0" />
<img width="773" height="553" alt="kubctl get nodes" src="https://github.com/user-attachments/assets/57ef460c-59bc-4a62-a132-5442ad2f2a11" />
<img width="758" height="538" alt="argocd-synced" src="https://github.com/user-attachments/assets/36d8f9b9-48bb-4af0-8fdc-de637ae45453" />
