# Network-policies-practice
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

## Network policies
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
In this configuration, the **ingress** (policy for incoming requests) allows any external 
connection from the internet to port 80 using TCP:
```yaml
  ingress:
    - from: []
      ports:
        - protocol: TCP
          port: 80
```
The **egress** (policy for outgoing requests) allows the container to only make requests to:

1. **The backend namespace** using TCP on port 3000:
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

2. **The Kubernetes DNS service** (in kube-system namespace) for name resolution using UDP on port 53:
```yaml
  - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
      ports:
        - protocol: UDP
          port: 53
```
The connection to the Kubernetes DNS is allowed for all the namespaces, therefore it's explanation will be omitted in the other services.
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
The *ingress* policy only allows incoming connection from the namespace of frontend, using port 3000 and the protocol TCP:
```yaml
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
```
The *egress* policy allows outgoing connections only to the database inthe namespace *database-ns*,using the port 5432 using TCP:
```yaml
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
The ingress policy allows only incoming connections to the backend namespace using the port 5432 and TCP:
```yaml
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
```
The egress policy denied any outgoing request:
```yaml
 egress: []
```
## Deployment and service
The first step in the deployment is to create the respective namespace for frontend, backend and database:
```yaml
# ============================================
# CREATE NAMESPACES
# ============================================
apiVersion: v1
kind: Namespace
metadata:
  name: frontend-ns
  labels:
    name: frontend-ns
---

apiVersion: v1
kind: Namespace
metadata:
  name: backend-ns
  labels:
    name: backend-ns

---
apiVersion: v1
kind: Namespace
metadata:
  name: database-ns
  labels:
    name: database-ns
```
Then define each deployment and it's respective service,for simplicity we will explain the common parts of the deployment and drrvice:
### Deployment
```yaml
metadata:
  name: <deployment-name>
  namespace: <namespace>
```
- **name**: Unique identifier for this deployment
- **namespace**: Logical isolation where the deployment lives
```yaml
spec:
  replicas: 1
  selector:
    matchLabels:
      app: <app-name>
```
- **replicas**: Number of pods running the app
- **matchLabels**: The label that identify to which deployment the pod belongs to.
```yaml
spec:
      containers:
      - name: <container-name>
        image: <image:tag>
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: <port>
```
- **name**: Name of the container
- **image**: Docker image to use (e.g., nginx:alpine, postgres:15)
- **imagePullPolicy**: Policy that controls how to access the image . It has three possible values:
  - IfNotPresent = Only download if not already on the node
  - Always = Always pull the latest image
  - Never = Must exist locally
- **containerPort**: Port where the application inside the container listens

Some applications need a initial configuration of variables, those variables are define en the section **env**:
```yaml
     env:
        - name: DB_HOST
          value: "database-service.database-ns.svc.cluster.local"
        - name: DB_USER
          value: "postgres"
```
### Service
```yaml
metadata:
  name: <service-name>
  namespace: <namespace>
```
- **name**: Becomes the DNS name for the service
```
spec:
  type: <type>
```
There are three types of service that determinates how it is exposed: ClusterIP,NodePort and LoadBalancer
```yaml
selector:
    app: <app-name>
```
- Indicates the label of the pods where the services will send traffic to.
```yaml
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080  # Only for NodePort type
```
- **port**: Port where other services/pods connect to this service
- **targetPort**: Port on the container where traffic is sent
- **nodePort**: Port exposed on the physical node. Range: 30000-32767
### Frontend:
```yaml
# ============================================
# DEPLOYMENT: FRONTEND
# ============================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: frontend:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: frontend-ns
spec:
  type: NodePort
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
---
```
### Backend:
```yaml
# ============================================
# DEPLOYMENT: BACKEND
# ============================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: backend:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
        env:
        - name: DB_HOST
          value: "database-service.database-ns.svc.cluster.local"  # ← CAMBIO IMPORTANTE
        - name: DB_USER
          value: "postgres"
        - name: DB_PASSWORD
          value: "example"

---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: backend-ns
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 3000
    targetPort: 3000

---
```
### Database:
```yaml
# ============================================
# DEPLOYMENT: DATABASE
# ============================================
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: database-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
  template:
    metadata:
      labels:
        app: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "example"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_DB
          value: "postgres"

---
apiVersion: v1
kind: Service
metadata:
  name: database-service
  namespace: database-ns
spec:
  type: ClusterIP
  selector:
    app: database
  ports:
  - port: 5432
    targetPort: 5432
```
As it seems the configuration is similar between the three elements but there are little differents like the frontend that has to be expose to internet so it has the type nodePort and the database that needs some variables defined in the extra section **env**.
## Apply deployment and network policies
Execute the following command to apply the deployment:
```bash
kubectl apply -f "archive name or location"
```
The same for the network policies
The pods should be running now:

<img width="1048" height="371" alt="Pasted image 20251008182243" src="https://github.com/user-attachments/assets/ab83f7fa-c76e-4355-b22e-b945c15bf9e3" />

Now we verify the creation of the policies:

<img width="955" height="130" alt="image" src="https://github.com/user-attachments/assets/7a30b744-f6ab-4af3-8940-6c6d5588d5bb" />

## Connection test
- Frontend to Backend:
- 
  <img width="1218" height="713" alt="image" src="https://github.com/user-attachments/assets/ea2a88ac-1f66-436f-bbdf-518df55581bd" />

- Front to Database:
- 
  <img width="689" height="86" alt="image" src="https://github.com/user-attachments/assets/310c8e88-76ce-476f-a724-8267ea0160d8" />
  
- Backend to Database:
- 
  <img width="1189" height="80" alt="image" src="https://github.com/user-attachments/assets/dc9d642d-fbfa-418b-b12b-12bcf69a27de" />

- Backend to Frontend:
- 
  <img width="1189" height="176" alt="image" src="https://github.com/user-attachments/assets/758dcbd4-d2e1-4d8a-9859-2dccbe440c70" />

- Database to Backend:
- 
  <img width="854" height="86" alt="image" src="https://github.com/user-attachments/assets/71539bab-8185-473e-be36-4229e21062c3" />

- Database to Frontend:
- 
  <img width="854" height="79" alt="image" src="https://github.com/user-attachments/assets/2da85ffe-d9ae-41f8-a55b-817449ccd5cc" />

Finally, we espose the frontend service to see that everything is working:

<img width="1455" height="419" alt="image" src="https://github.com/user-attachments/assets/959a1cfb-6152-4ec0-9db3-ffbfe93e53f5" />

<img width="563" height="159" alt="image" src="https://github.com/user-attachments/assets/5b00a0e4-05c6-4189-a141-9eedc0b9dfa4" />


