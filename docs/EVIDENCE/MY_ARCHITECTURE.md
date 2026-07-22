**1. TOPOLOGY DIAGRAM**
                                    Internet
                                       │
                          DNS: taskapp.yourdomain.com
                              api.yourdomain.com
                                       │
                                       ▼
                        ┌──────────────────────────────┐
                        │   Ingress Controller (NGINX) │
                        │   External IP: <ELB/IP>      │
                        │   TLS terminated by cert-manager│
                        └──────────────────────────────┘
                                       │
                              ┌────────┴────────┐
                              ▼                 ▼
                  ┌─────────────────┐  ┌─────────────────┐
                  │  Frontend       │  │  Backend        │
                  │  Service (80)   │  │  Service (5000) │
                  │  ClusterIP      │  │  ClusterIP      │
                  └─────────────────┘  └─────────────────┘
                              │                 │
                              ▼                 ▼
                  ┌─────────────────┐  ┌─────────────────────────────┐
                  │  Frontend Pods  │  │  Backend Pods               │
                  │  2 replicas     │  │  2 replicas                 │
                  │  Nodes: w1, w2  │  │  Nodes: w1, w2              │
                  │  React/Nginx    │──│  Flask API                   │
                  └─────────────────┘  │  /api → backend:5000        │
                              │        └─────────────────────────────┘
                              │                         │
                              └─────── /api proxy ──────┘
                                                        │
                                                        ▼
                                          ┌─────────────────────────┐
                                          │  Postgres Service       │
                                          │  Headless (ClusterIP:None)│
                                          │  port 5432              │
                                          └─────────────────────────┘
                                                        │
                                                        ▼
                                          ┌─────────────────────────┐
                                          │  Postgres StatefulSet   │
                                          │  postgres-0             │
                                          │  PersistentVolumeClaim  │
                                          │  Node: w1               │
                                          └─────────────────────────┘
                    ┌─────────────────────────────────────────────────┐
                    │              control Plane (k3s Server)        │
                    │              Node: cp (t3.micro)               │
                    │              Runs API Server, Scheduler        │
                    │              **No app workloads**              │
                    └─────────────────────────────────────────────────┘
                    ┌─────────────────────────────────────────────────┐
                    │              Worker Nodes (2x t3.micro)        │
                    │              Run all app pods                  │
                    └─────────────────────────────────────────────────┘

**2. NODE AND NETWORK**
Nodes (AWS EC2)
   Role	           Instance Type	              AZ/Region	  OS	          Purpose
a. Control Plane	 t3.micro (1 vCPU, 1 GB RAM)	us-east-1a	Ubuntu 22.04	k3s server (API, scheduler, controller) – no workloads
b. Worker 1	       t3.micro (1 vCPU, 1 GB RAM)	us-east-1a	Ubuntu 22.04	Runs PostgreSQL, Backend, Frontend pods
c. Worker 2	       t3.micro (1 vCPU, 1 GB RAM)	us-east-1a	Ubuntu 22.04	Runs Backend, Frontend pods (HA)

NETWORK (VPC & SUBNET)
VPC CIDR: 10.0.0.0/16

Subnet CIDR: 10.0.1.0/24 (public subnet with map_public_ip_on_launch = true)

Why: A single /24 subnet within a /16 VPC is simple, cost-effective, and provides 254 IP addresses – more than enough for this cluster. The VPC CIDR allows future expansion to additional subnets if needed.

FIREWALL (Security Group)
Port     	          Source             	    Purpose
22 (SSH)	          MY_PUBLIC_IP/32	        Ansible provisioning and administrative access
80 (HTTP)	          0.0.0.0/0	Ingress       Traffic (redirected to HTTPS)
443 (HTTPS)	        0.0.0.0/0	              Application traffic (TLS terminated at Ingress)
6443 (kube-api)	    10.0.0.0/16 (VPC only)	CLOSED to the internet – internal cluster communication only
Why 6443 is closed: The Kubernetes API port is not exposed to the internet as a hard security requirement. Instead, I use an SSH tunnel (-L 6443:localhost:6443) to access the API server from my laptop. This ensures:

No brute-force attacks on the API.

Compliance with capstone constraints.

Traffic stays inside the VPC (fast, free, secure).

Additional Network Security
UFW enabled on all nodes: allows only SSH (22), HTTP (80), HTTPS (443) from the internet.

Node-to-node communication: all ports are open within the security group (self-referencing rule) for k3s/flannel overlay.

**3. REQUEST FLOW (One Paragraph)**
A user's request flows as follows: DNS (taskapp.yourdomain.com or api.yourdomain.com) resolves to the Ingress Controller's external IP (AWS ELB or node IP). The Ingress Controller (NGINX) terminates TLS using a certificate issued by cert-manager (Let's Encrypt) and routes the traffic based on the host header. For taskapp.yourdomain.com, it forwards traffic to the frontend Service (port 80), which load-balances to one of the frontend Pods (React/Nginx, 2 replicas). The frontend application makes API calls to /api/*, which are proxied by the frontend's Nginx configuration to the backend Service (backend:5000). The backend Service load-balances to one of the backend Pods (Flask, 2 replicas). The backend application reads from and writes to the PostgreSQL database via the postgres Service (port 5432), which resolves to the PostgreSQL StatefulSet pod (postgres-0). The database uses a PersistentVolumeClaim for durable storage, ensuring data survives pod restarts and node failures.


**4. The single-server assumptions you fixed**
   Assumption 1: Migrations run in the container entrypoint (alembic upgrade head on boot)
   Why it breaks at scale:
   Two or more backend replicas start simultaneously → they race on the database schema, causing deadlocks, rollbacks, or corrupted migrations.

   How i fixed it:
   Created a separate Kubernetes Job (db-migration) that runs once before the backend Deployment scales up. Used Argo CD sync-wave: 5 to order the Job correctly and prevent the race condition.

   Assumption 2: Persistent storage uses a named volume on the host
   Why it breaks at scale:
   Pods are scheduled on different nodes – a volume on one node is not accessible from another. If the pod reschedules, data is lost.

   How i fixed it:
   PostgreSQL runs as a StatefulSet with a PersistentVolumeClaim (PVC). The PVC persists data across restarts and node rescheduling, ensuring the database survives pod failures and node drains.

   Assumption 3: Traffic routing uses ports: published on the host
   Why it breaks at scale:
   With multiple replicas on multiple nodes, a single host port is not enough; external traffic cannot reach the correct pod, and load‑balancing is impossible.

   How i fixed it:
   Exposed the frontend and backend via ClusterIP Services and deployed an Ingress Controller (NGINX) as the single entry point. The Ingress routes traffic based on host/path and load‑balances across the replicas.

   Assumption 4: Self‑healing – manual restarts when pods die
   Why it breaks at scale:
   In a cluster, pods can die on any node – manual intervention is not acceptable, especially under load.

   How i fixed it:
   Used Deployments with ReplicaSets – the controller automatically replaces failed or crashed pods, ensuring the desired replica count is always met, without any manual action.

   Assumption 5: Zero‑downtime deployments – traffic stops during docker stop/restart
   Why it breaks at scale:
   When pods are updated, traffic must continue flowing to healthy pods; a simple restart drops in‑flight requests.

   How i fixed it:
   Used a RollingUpdate strategy with maxUnavailable: 0. The new replica is started before the old one is terminated, ensuring 100% availability during updates. Added readiness probes so traffic only goes to ready pods.

   Assumption 6: Secrets – plaintext environment files (SECRET_KEY, DB_PASSWORD) stored in git or injected as plaintext
   Why it breaks at scale:
   Git history is forever – secrets get exposed. Also, secrets need to be consistently synced across all replicas.

   How i fixed it:
   Created Kubernetes Secrets out‑of‑band (manually with kubectl create secret), never committed to git. The secret.yaml file is added to .gitignore. Sealed Secrets was explored for full GitOps compliance but skipped due to memory constraints on t3.micro.

   Assumption 7: Pod placement – all pods run on the same host
   Why it breaks at scale:
   If that host fails, all pods are lost. Also, resource contention (CPU/memory) degrades performance.

   How i fixed it:
   Added topologySpreadConstraints to the backend and frontend Deployments (maxSkew: 1, topologyKey: kubernetes.io/hostname). This forces replicas to land on different nodes, ensuring high availability and balanced resource usage.

   Assumption 8: Single point of failure for the database
   Why it breaks at scale:
   The database runs on a single pod. If that pod fails or the node dies, the application loses all data and becomes unavailable.

   How i fixed it:
   PostgreSQL runs as a StatefulSet with podAntiAffinity (implicitly) and a PersistentVolumeClaim. While we still have only one database replica (due to t3.micro constraints), the PVC ensures data survives pod restarts, and the StatefulSet provides a stable network identity. A future improvement would be to use a managed database (RDS) or run PostgreSQL with repmgr for true HA.


**5. CHOICES AND TRADE-OFFS**
Raw YAML vs Helm vs Kustomize — Why Raw YAML?
I chose raw YAML because:

Simplicity: This is a capstone project with a single environment (production). Raw YAML is explicit, easy to read, and directly traceable to the requirements.

Transparency: You can see exactly what each resource does without needing to understand templating.

GitOps Compatibility: Argo CD handles raw YAML perfectly with syncPolicy.automated.

No Over-engineering: Helm would be overkill for a single application with one environment. I would consider Helm for a multi-environment setup (dev/staging/prod).

**Ingress-nginx vs k3s Traefik — Why Ingress-nginx?**
I chose ingress-nginx because:

Better TLS/ACME integration: cert-manager works more seamlessly with NGINX.

More mature: NGINX has a wider community, better documentation, and more battle-tested features.

Path-based routing: More flexible routing rules.

k3s Traefik was disabled during k3s installation with --disable traefik to avoid conflicts and reduce memory footprint on t3.micro.

**CNI / NetworkPolicy Enforcement — What and Why?**
CNI: k3s uses Flannel as the default CNI (Container Network Interface). This provides the overlay network for pod-to-pod communication across nodes.

NetworkPolicy Enforcement: Flannel does not enforce NetworkPolicy by default. I included NetworkPolicy manifests (manifests/networkpolicy/network-policy.yaml) to define the desired traffic rules. However, on t3.micro, full CNI policy enforcement (e.g., Calico) would add significant memory overhead. Therefore, the NetworkPolicy resources are declared in Git but may not be enforced without installing Calico. This trade-off was made to prioritize cluster stability on limited hardware. For a production environment on larger instances, I would install Calico and enable full policy enforcement.

NetworkPolicy rules defined:

default-deny for the taskapp namespace (only ingress is allowed).

Allow frontend → backend (port 5000).

Allow ingress-nginx → frontend (port 80) and backend (port 5000).

**Secrets Approach — Out-of-Band vs Sealed Secrets — Why?**
I initially attempted to use Sealed Secrets for full GitOps secret management, but it failed consistently on t3.micro instances due to memory pressure (the Sealed Secrets controller was OOM‑killed).

Instead, I used the Out-of-Band approach:

Created the secret manually with kubectl create secret generic taskapp-secret -n taskapp ....

Added manifests/secret.yaml to .gitignore.

Documented the commands in RUNBOOK.md so a teammate can recreate it.

Trade-off: This breaks the "everything in Git" ideal but is pragmatic for the capstone. In a production environment with larger instances, I would use Sealed Secrets (or External Secrets Operator) to fully automate secret management while keeping git clean.

**6. ADDITIONAL NOTES**
Why t3.micro?
AWS Free Tier eligible (1 vCPU, 1 GB RAM).

Sufficient for the capstone with memory-saving k3s flags (--disable traefik, --disable servicelb, --disable local-storage, --disable network-policy, --disable-agent).

Swap enabled (1 GB) to handle memory pressure.

GitOps Workflow
Argo CD syncs the manifests/ folder from the main branch.

Commit → push → Argo auto-syncs (prune + self-heal).

Full audit trail via Git history.

**Monitoring & Observability**
metrics-server installed for HPA and kubectl top.

HPA scales Backend from 2 to 5 replicas based on CPU/Memory utilization.




                    
