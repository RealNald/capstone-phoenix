**COST**

This echoes the Docker lesson's "why one server" thread — except now the answer to "is the extra cost worth it?" is yours to argue.

**Monthly itemized cost**
Item	                                   Spec	                                          Qty	          $/mo
Control-plane VM (AWS EC2 t3.micro)    	1 vCPU, 1 GB RAM, 20 GB gp3 root volume       	1	            ~$8.76
Worker VMs (AWS EC2 t3.micro)         	1 vCPU, 1 GB RAM, 20 GB gp3 root volume	        2           	~$17.52
Elastic IPs (if used)	                  Public static IPs for nodes	3	~$10.80
Load Balancer (AWS NLB or ELB)	        Network Load Balancer (NLB) or Classic ELB	    1	            ~$18.25
Block storage (PVC)                     10 GB gp3 (PostgreSQL PVC)	1	~$1.00
Object storage (S3)	                    Terraform remote state + backups (~5 GB)        1 bucket	    ~$0.15
Domain / DNS (Route 53)	                1 hosted zone + 2 A records                    	1	            ~$0.50
Data transfer (estimated 50 GB outbound)	Internet egress @ $0.09/GB	                  50 GB       	~$4.50
Argo CD & platform overhead	            CPU/memory usage on cluster           (no extra cloud cost)     $0.00

**Total			~$61.48 / month**

**Note: If you use AWS Free Tier (eligible for 12 months), you get:
>750 hours/month of t2/t3.micro EC2 usage → covers 1 instance.
>5 GB of S3 standard storage → covers state & backups.
>1 GB of data transfer out per month.**

Real-world cost after Free Tier: ~$61.48/month (or ~$50.68 if you don't use Elastic IPs and use a single EIP for the control plane only).

**Compared to the single-server Compose+Portainer deploy**
-That stack cost roughly:
>Single EC2 t3.micro: ~$8.76/month
>No load balancer, no PVC, no Elastic IPs
>Total: ~$8.76/month + data transfer

-This Kubernetes cluster costs:
> $61.48/month (or ~$50.68 without Elastic IPs)

-What the extra spend buys (be honest — tie to §0 of the brief):
   1. High Availability
   What it buys: 2 worker nodes + 1 control plane.
   Why it matters:
   If one worker dies, the app continues running on the other worker.
   The control plane is the single point of failure (could be mitigated with 3 control planes, but that would cost more).

   2. Zero-downtime deployments
   What it buys: Rolling updates with maxUnavailable: 0 and readinessProbes.
   Why it matters:
   You can deploy new versions of the app without dropping a single user request – critical for production services where downtime equals lost revenue or reputation.

   3. Autoscaling
   What it buys: HPA (Horizontal Pod Autoscaler) scales the Backend from 2 to 5 replicas based on CPU and memory utilization.
   Why it matters:
   During traffic spikes, your app automatically scales to handle the load; during low traffic, it scales down to save resources and reduce costs.

   4. Self-healing
   What it buys: Kubernetes Deployments + ReplicaSets.
   Why it matters:
   If a pod crashes, it restarts automatically. If a node fails, pods reschedule to healthy nodes. No manual intervention required – the system repairs itself.

   5. Multi-node resilience
   What it buys: Pods spread across different nodes via topologySpreadConstraints (maxSkew: 1, topologyKey: kubernetes.io/hostname).
   Why it matters:
   A single node failure does not take down the entire application; the remaining pods on healthy nodes continue serving traffic, ensuring availability.

   6. Persistent storage
   What it buys: PVC (PersistentVolumeClaim) + StatefulSet for PostgreSQL.
   Why it matters:
   Database data survives pod restarts and node failures. Data integrity is maintained even after rescheduling, unlike host-bound storage that disappears when a pod moves to another node.

   7. GitOps (Argo CD)
   What it buys: Auto-sync from Git with syncPolicy.automated (prune + selfHeal).
   Why it matters:
   Full audit trail, instant rollback to any previous commit, and the ability to trace every change to a specific Git commit. No manual kubectl operations in the final state – the cluster owns itself.

   8. Security (by design)
   What it buys: Kubernetes API (6443) closed to the internet; secrets managed out-of-band; SSH tunnel for kubectl access.
   Why it matters:
   The cluster is not exposed to the public internet, reducing attack surface. Secrets are never committed to git, preventing accidental exposure. SSH access is restricted to your IP only.

   9. Centralized Ingress & TLS management
   What it buys: NGINX Ingress Controller + cert-manager (Let's Encrypt) for automated TLS certificate issuance and renewal.
   Why it matters:
   All incoming traffic goes through a single entry point where TLS is terminated centrally. Certificates are renewed automatically, eliminating manual certificate management and the risk of expired certificates.


**When is it NOT worth it?**
-If your application has low traffic (e.g., < 100 requests/day).
-If you have strict budget constraints (e.g., $10/month limit).
-If you don't need HA – for development or internal tools, a single node is cheaper and simpler.
-If your team does not have Kubernetes expertise – the operational overhead is higher than a simple Docker Compose + Portainer setup.

**How I'd halve this**
One concrete paragraph: spot/preemptible workers? smaller control-plane? k3s on 2 nodes? shared ingress?

**To cut the monthly cost in half, I would:**
-Use spot/preemptible instances for the two workers (saves ~60–70% on EC2 costs) – but accept that workers may be terminated at any time, which is acceptable if the application is stateless and can reschedule quickly. Use a Spot instance for the control plane only if you can tolerate brief downtime (not recommended for production).
-Drop the Elastic IPs – use the ephemeral public IPs that come with EC2. You'll need to update your inventory.ini and kubeconfig after each restart, but this is fine for a development or demo environment. Use a single Elastic IP only for the Ingress Controller (if you need a stable external endpoint).
-Use a single t3.medium node with k3s running both control plane and workloads (no dedicated workers) – this would cost about $17/month. However, this would lose all HA benefits and is essentially a "single-node cluster" (which violates the capstone requirements but is a valid cost-cutting measure for non-critical workloads).
-Run on 2 nodes (not 3) – combine the control plane with a worker (the --disable-agent flag on the control plane is optional; you can let it run workloads). This would save one EC2 instance (~$8.76/month) but reduce resilience.
-Use a shared ingress controller – if you have multiple clusters or applications, you can run a single NGINX Ingress Controller across them to share the load balancer cost.
-Use cheaper storage – gp2 volumes are cheaper than gp3 (but slower). For a PostgreSQL database with low write volume, gp2 is fine.
-Schedule the cluster to shut down at night – for a development environment, you can shut down EC2 instances during off-hours (e.g., 10 PM – 6 AM) to save ~50% of compute costs.
-Use a cheaper cloud provider – Hetzner Cloud or DigitalOcean offer similar specs for ~$4–$6 per VM, cutting the total cost to ~$20–$30/month.





