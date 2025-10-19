# network-policies-practice
This github is an simple implementation of an layer-based security model with minikube that will contain 3 components frontend,backend and database, over them it will apply network policies to restrain connections as following:
#### Allow:
- Frontend to Backend
- Backend to Database
#### Denied:
- Backend to Frontend
- Frontend to Database
- Database to Backend
- Database to Frontend
### Minikube configuration
For our minikube container to handle the communications between containers with the stablish policies, it is necessary to add a cni, in this case calico:
<img width="1286" height="419" alt="Pasted image 20251006162323" src="https://github.com/user-attachments/assets/c4e460a9-94fe-43fa-baef-ab18a1512aab" />

Now we ensure the calico containers are running:
<img width="941" height="76" alt="Pasted image 20251008150115" src="https://github.com/user-attachments/assets/aa67ba00-5602-4116-8ff3-69338dd78cd9" />

### Network policies
The network policies for the cluster hacve the following configuration:
- Frontend:
```yaml
# ============================================
# NETWORK POLICY: FRONTEND
# ============================================
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-network-policy
  namespace: frontend-ns
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    - from: []
      ports:
        - protocol: TCP
          port: 80
  
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: backend-ns
          podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 3000
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```
In this configuration the ingress(Politic for incoming request) allows any external connection from internet to the port 80 using TCP:
```yaml
  ingress:
    - from: []
      ports:
        - protocol: TCP
          port: 80
```
And egress(Politic for outcoming request) allows the container only to do request to the backend namespace using TCP and the port 3000:
```yaml
 - to:
        - namespaceSelector:
            matchLabels:
              name: backend-ns
          podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 3000
```


and the internal dns of minikube for communication:
```yaml
 - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```
- Backend:
```yaml
# ============================================
# NETWORK POLICY: BACKEND (API)
# ============================================
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-network-policy
  namespace: backend-ns
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: frontend-ns
          podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 3000
  
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: database-ns
          podSelector:
            matchLabels:
              app: database
      ports:
        - protocol: TCP
          port: 5432
    # DNS resolution
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```

- Database:
```yaml
# ============================================
# NETWORK POLICY: DATABASE
# ============================================
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-network-policy
  namespace: database-ns
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: backend-ns
          podSelector:
            matchLabels:
              app: backend
      ports:
        - protocol: TCP
          port: 5432
  
  egress: []
```
