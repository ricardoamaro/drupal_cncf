This how-to guide focus on a scenario where Drupal is tested using Tekton and the deployment of all applications (including Drupal, MariaDB, Prometheus, and Grafana) is managed via Argo CD.
CI/CD pipeline is using Tekton for testing and Argo CD for deployment. This approach requires defining the application configurations declaratively in a Git repository, which Argo CD will use to manage deployments in the Kubernetes cluster.

### Prerequisites

Ensure you have the following prerequisites installed and configured:
- Docker
- `kubectl`
- `kind` or `k3d`
- `helm`
- `kubectl-argo-rollouts` plugin for Argo CD interaction (optional but useful)
- Access to a Git repository to store your Kubernetes manifests and Tekton pipelines

Ensure Docker, kubectl, kind/k3d, helm, and git are installed on your system.

### Step 1: Create a Cluster

1. **Create a Cluster using k3d**

    ```bash
    k3d cluster create my-cluster \
      --port "80:80@loadbalancer" \
      --port "443:443@loadbalancer" \
      --agents 1
    ```


    ```bash
    k3d cluster list
    ```

1. **Alternatively a cluster can be created using kind**

    Create a Cluster Configuration File** (`kind-config.yaml`):

        ```yaml
        kind: Cluster
        apiVersion: kind.x-k8s.io/v1alpha4
        nodes:
          - role: control-plane
            extraPortMappings:
              - containerPort: 80
                hostPort: 80
                protocol: TCP
              - containerPort: 443
                hostPort: 443
                protocol: TCP
          - role: worker
        ```

    Create the kind Cluster:

        ```bash
        kind create cluster --config kind-config.yaml
        ```

### Step 2: Install Argo CD

1. **Ckeck access to the cluster**

    ```bash
    kubectl cluster-info
    ```

1. **Install Argo CD in the Cluster**:

    ```bash
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    ```
1. **Retrieve the Argo CD Admin Password**:

    Initially, Argo CD auto-generates a password for the `admin` account. This password is stored in a Kubernetes secret within the Argo CD namespace. You can retrieve it by executing the following command:

    ```bash
    kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
    ```

    This command fetches the password from the `argocd-initial-admin-secret` secret, decodes it from Base64, and prints it to your terminal.

1. **Access the Argo CD UI via Port-Forwarding**:

    Setup port-forwarding with the command:

    ```bash
    kubectl port-forward svc/argocd-server -n argocd 8080:443
    ```

    Access the Argo CD web UI at [http://localhost:8080](http://localhost:8080). Since the service is exposed over HTTPS and you're forwarding to HTTP, you might need to proceed with caution if your browser warns you about the site's security certificate.

1. **Login to Argo CD**:

    - **Username**: The default username is `admin`.
    - **Password**: Use the password retrieved from the `argocd-initial-admin-secret` secret.

    For login via the command line:

    ```bash
    argocd login localhost:8080 --insecure
    ```

1. **(Optional) Change the Admin Password**:

    For security reasons, it's a good practice to change the default admin password. You can do this from the Argo CD UI or by using the Argo CD CLI. If you have the CLI installed, you can execute the following command to change the password:

    ```bash
    argocd account update-password
    ```

    You'll be prompted to enter the current password (retrieved in step 1), and then you can set a new password.

#### Deploy the Root Application to Argo CD

Next steps are only required if you are kick stating manually a new repository.

You can deploy the existing root application to Argo CD using the Argo CD CLI or the UI:

* Using the CLI:

First, make sure you're logged into your Argo CD instance:

    ```bash
    argocd login <ARGOCD_SERVER>
    ```

Then, create the root application:

    ```bash
    argocd app create -f argoapps/root.yaml
    ```

* Using the UI:

        Navigate to your Argo CD UI.
        Click on "New App".
        Fill in the details according to your root.yaml content.
        Click "Create".

* Verify and Manage Your Applications

Once the root application is deployed, Argo CD will automatically detect, deploy, and manage all applications defined in the argoapps/ directory as specified in this Git repository. You can verify the status of all applications in the Argo CD dashboard or CLI:

    ```bash
    argocd app list
    ```

You should see the root application along with all other applications it manages. Any changes made to these application definitions in the Git repository will be automatically synced by Argo CD, adhering to the GitOps principles.


### 3. Prepare Your Git Repository

Clone or initialize a Git repository to store your Kubernetes manifests. In this repository, create directories for each of the applications (Drupal, MySQL, Prometheus, Grafana) and Tekton configurations. Example structure:

```
/
|-- drupal/
|-- mysql/
|-- prometheus/
|-- grafana/
|-- tekton/
```

    ```bash
    mkdir drupal mariadb prometheus grafana tekton
    ```

Inside each directory, add the necessary Kubernetes manifests or Helm charts. For Tekton, define your CI pipeline for testing Drupal.

### 4. Install Tekton Pipelines

Install Tekton Pipelines in your cluster:

    ```bash
    kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
    ```

#### Installing the Tekton Dashboard

1. **Install the Tekton Dashboard**:

   Tekton provides a web-based UI - the Tekton Dashboard. Install it by running:

   ```bash
   kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
   ```

2. **Access the Tekton Dashboard**:

   Once installed, you can access the Dashboard by using `kubectl` to port-forward the Dashboard service to your local machine:

   ```bash
   kubectl --namespace tekton-pipelines port-forward svc/tekton-dashboard 9097:9097
   ```

   Now, you can access the Tekton Dashboard by navigating to [http://localhost:9097](http://localhost:9097) in your web browser.


### Define a Tekton Pipeline for Testing in a Drupal container

In the `tekton/` directory, create YAML files for your Tekton tasks and pipeline that define how to test a Drupal container. This could involve linting, unit tests, and any other checks relevant to your Drupal site.

- **Example Tekton Task** (`tekton/drupal-test-task.yaml`):

    ```yaml
    apiVersion: tekton.dev/v1beta1
    kind: Task
    metadata:
      name: drupal-test
    spec:
      steps:
        - name: lint
          image: drupal:latest
          script: |
            #! /bin/bash
            echo "Running Drupal linting..."
    ```

- **Example Tekton Pipeline** (`tekton/drupal-test-pipeline.yaml`):

    ```yaml
    apiVersion: tekton.dev/v1beta1
    kind: Pipeline
    metadata:
      name: drupal-test-pipeline
    spec:
      tasks:
        - name: drupal-lint
          taskRef:
            name: drupal-test
    ```
Create a pipeline that uses this task in `drupal-test-pipeline.yaml`.

   ```bash
   kubectl apply -f tekton/drupal-test-task.yaml
   kubectl apply -f tekton/drupal-test-pipeline.yaml
   ```

### Defining a Tekton Pipeline for Drupal Unit Tests

Or you can git clone and run Drupal unit tests with Tekton, with a `Task` that will execute the tests, and then a `Pipeline` that uses this task:

1. **Create a Tekton Task for Drupal Unit Tests** (`tekton/drupal-unit-test-task.yaml`):

   This Task example uses a generic PHP container to run `phpunit` for Drupal's unit tests. Adjust the commands based on your specific Drupal setup and test configuration.

   ```yaml
   apiVersion: tekton.dev/v1beta1
   kind: Task
   metadata:
     name: drupal-unit-test
   spec:
     steps:
       - name: run-tests
         image: php:7.4-cli
         script: |
           #!/bin/bash
           set -e
           apt-get update && apt-get install -y git
           git clone https://your-drupal-repo.git /drupal
           cd /drupal
           # Install dependencies, e.g., with Composer
           composer install
           # Run unit tests, adjust the path as necessary
           ./vendor/bin/phpunit --configuration ./web/core/phpunit.xml.dist ./web/modules/custom
   ```

2. **Create a Tekton Pipeline to Execute the Task** (`tekton/drupal-unit-test-pipeline.yaml`):

   Define a Pipeline that uses the `drupal-unit-test` task.

   ```yaml
   apiVersion: tekton.dev/v1beta1
   kind: Pipeline
   metadata:
     name: drupal-unit-test-pipeline
   spec:
     tasks:
       - name: drupal-unit-tests
         taskRef:
           name: drupal-unit-test
   ```

   Apply this Task to the cluster:

   ```bash
   kubectl apply -f tekton/drupal-unit-test-task.yaml
   kubectl apply -f tekton/drupal-unit-test-pipeline.yaml
   ```

### Running the Pipeline

With the Task and Pipeline defined, you can now run your Drupal unit tests through Tekton:

1. **Start the Pipeline**:

   Use the [Tekton CLI `tkn`](https://tekton.dev/docs/cli/) to start the pipeline:

   ```bash
   tkn pipeline start drupal-unit-test-pipeline --showlog
   ```

   This command starts the pipeline and shows the logs in your terminal, allowing you to monitor the test execution.

2. **Monitor the Pipeline Execution**:

   If you prefer to use the Tekton Dashboard, you can monitor the pipeline execution, view logs, and check test results directly from the UI at [http://localhost:9097](http://localhost:9097).


### 6. Configure Argo CD Applications

For each application (Drupal, MariaDB, Prometheus, Grafana), create an Argo CD Application manifest in the the repository root or in a folder. These manifests should point to the respective directories within the same repository where the Kubernetes manifests or Helm charts are stored.

- **Example Argo CD Application for MariaDB** (`argo-app-mariadb.yaml`):

    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: mariadb
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: 'https://your-git-repo-url.git'
        path: mariadb
        targetRevision: HEAD
        helm:
          valueFiles:
            - values.yaml
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: drupal
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
    ```

- **MariaDB Values File** (`mariadb/values.yaml`):

    ```yaml
    auth:
      rootPassword: "secretpassword"
      database: "drupaldb"
    ```


Example `argo-app-drupal.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: drupal
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://your-git-repo-url.git'
    path: drupal
    targetRevision: HEAD
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: drupal
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

Commit and push these configurations to your Git repository.

### 7. Deploy Applications Using Argo CD

Use Argo CD CLI or UI to create applications based on the manifests you've pushed to your Git repository. Argo CD will monitor these configurations and manage the deployment of MySQL, Drupal, Prometheus, and Grafana according to the manifests.

```bash
argocd app create -f argo-app-drupal.yaml
```

Repeat for MariaDB, Prometheus, and Grafana.

### 8. Running Tekton Pipeline

Trigger the Tekton pipeline to test Drupal:

```bash
tkn pipeline start drupal-test-pipeline --showlog
```

Monitor the pipeline run in Tekton:

```bash
tkn pipelinerun list -n tekton-pipelines
```

### Step 9: Accessing Services

Use `kubectl port-forward` to access Drupal and Grafana:

- **Drupal**:

    ```bash
    kubectl port-forward svc/drupal 8080:80 -n drupal
    ```

- **Grafana**:

    ```bash
    kubectl port-forward svc/grafana 3000:80 -n monitoring
    ```

Focusing on setting up Prometheus and Grafana for monitoring, and finalizing the deployment of Drupal with MariaDB using Argo CD.

### Step 10: Deploy Prometheus and Grafana with Argo CD

For monitoring your applications, you need to deploy Prometheus and Grafana. Similar to MariaDB, you will define Argo CD Application manifests for both.

To populate the `prometheus/` and `grafana/` directories in your Git repository for use with Argo CD and Helm, you'll typically include Helm values files that customize the deployments according to your needs. This approach allows Argo CD to deploy these applications using Helm's templating capabilities, with settings that enable Prometheus and Grafana to work together seamlessly.

#### Setting Up Prometheus

1. **Create a values file for Prometheus** (`prometheus/values.yaml`):

   This file will customize the Prometheus Helm chart. For integrating Prometheus with Grafana, ensure that service discovery is configured correctly, and consider enabling persistent storage for Prometheus metrics.

   Example `prometheus/values.yaml`:

   ```yaml
   alertmanager:
     enabled: false
   pushgateway:
     enabled: false
   server:
     persistentVolume:
       enabled: true
       size: 10Gi
     service:
       type: ClusterIP
       port: 9090
     extraScrapeConfigs: |
       - job_name: 'kubernetes-pods'
         kubernetes_sd_configs:
           - role: pod
         relabel_configs:
           - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
             action: keep
             regex: true
           - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
             action: replace
             target_label: __metrics_path__
             regex: (.+)
           - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
             action: replace
             regex: ([^:]+)(?::\d+)?;(\d+)
             replacement: $1:$2
             target_label: __address__
   ```

   This configuration disables some components you might not need (like Alertmanager and Pushgateway) and sets up a persistent volume for Prometheus. It also configures Prometheus to scrape metrics from pods annotated with `prometheus.io/scrape: "true"`.

2. **Add an Argo CD application manifest for Prometheus**:

   In your Git repository, create an Argo CD application manifest (`argo-app-prometheus.yaml`) that points to the Prometheus directory. This file tells Argo CD where to find the Helm values for the Prometheus deployment.

   Example `argo-app-prometheus.yaml`:

   ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: prometheus
      namespace: argocd
    spec:
      destination:
        name: in-cluster
        namespace: argocd
      project: default
      source:
        repoURL: 'https://prometheus-community.github.io/helm-charts'
        chart: kube-prometheus-stack
        targetRevision: 58.2.2
        helm:
          valueFiles:
            - values.yaml
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
          sync: true
    ```

#### Setting Up Grafana

1. **Create a values file for Grafana** (`grafana/values.yaml`):

   Configure Grafana to use Prometheus as a data source. You can also enable persistence and set admin credentials.

   Example `grafana/values.yaml`:

   ```yaml
   persistence:
     enabled: true
     size: 5Gi
   adminUser: admin
   adminPassword: <your-strong-password>
   datasources:
     datasources.yaml:
       apiVersion: 1
       datasources:
       - name: Prometheus
         type: prometheus
         url: http://prometheus-server.monitoring.svc.cluster.local:9090
         access: proxy
         isDefault: true
   ```

   This configuration sets up Grafana with a default data source pointing to the Prometheus server you deployed in the previous step.

2. **Add an Argo CD application manifest for Grafana**:

   Similar to Prometheus, create an Argo CD application manifest (`argo-app-grafana.yaml`) for Grafana in your repository.

   Example `argo-app-grafana.yaml`:

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: grafana
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: 'https://your-git-repo-url.git'
       path: grafana
       targetRevision: HEAD
       helm:
         valueFiles:
           - values.yaml
     destination:
       server: 'https://kubernetes.default.svc'
       namespace: monitoring
     syncPolicy:
       automated:
         selfHeal: true
         prune: true
   ```

### Deploying with Argo CD

With these configurations in place, commit and push your changes to the Git repository. Then, use Argo CD to create applications from the `argo-app-prometheus.yaml` and `argo-app-grafana.yaml` manifests. Argo CD will deploy Prometheus and Grafana based on your configurations, with Grafana automatically configured to use Prometheus as a data source.

Add helm repositories

    ```bash
    argocd repo add https://prometheus-community.github.io/helm-charts --type helm --name stable
    ```

### Step 11: Deploy Drupal with Argo CD

For deploying Drupal and connecting it to the MariaDB database, you'll follow a similar process as with MariaDB, Prometheus, and Grafana. Create an Argo CD Application manifest for Drupal.

- **Argo CD Application for Drupal** (`argo-app-drupal.yaml`):

    ```yaml
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: drupal
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: 'https://your-git-repo-url.git'
        path: drupal
        targetRevision: HEAD
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: drupal
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
    ```

- In the `drupal/` directory, include the Drupal Helm chart or Kubernetes manifests. You might need a `values.yaml` file to specify Drupal configuration, such as the database connection details.

### Step 12: Accessing Drupal and Grafana

After deploying Drupal and Grafana using Argo CD, and once everything is up and running, you can access these services:

- **Drupal**: As previously mentioned, use port-forwarding to access the Drupal service on your local machine.

- **Grafana**: Retrieve the Grafana admin password (if using the default admin account) and use port-forwarding to access the Grafana dashboard. Configure Grafana to use Prometheus as a data source to monitor your Drupal application.

### Final Notes

This guide provides an overview of deploying a full-stack application with monitoring on a local Kubernetes cluster managed by Kind, utilizing modern DevOps tools like Argo CD for GitOps and Tekton for CI. Specific details, such as the content of Kubernetes manifests, Helm `values.yaml` files, and Tekton pipeline configurations, require customization based on your application's architecture, the complexity of tests, and monitoring requirements.

Remember to push all your configuration files to your Git repository and use Argo CD to sync those configurations to your cluster. This GitOps approach ensures that your infrastructure and applications are version-controlled, easily recoverable, and transparent.
