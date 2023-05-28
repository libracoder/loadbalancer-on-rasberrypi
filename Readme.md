# Configuring MetalLB on Raspberry Pi

This readme file provides step-by-step instructions to configure MetalLB, a load balancer implementation for Kubernetes, on a Raspberry Pi cluster. MetalLB allows you to allocate external IP addresses to services running within your cluster.

## Prerequisites

Before you begin, ensure that you have the following:

- Raspberry Pi cluster with Kubernetes installed.
- Access to the Raspberry Pi cluster via `kubectl` command-line tool.
- Helm and kubectl installed on your local machine.

## Steps

Follow the steps below to configure MetalLB on your Raspberry Pi cluster:

1. Create a Kubernetes namespace for MetalLB by adding the following configuration to your Terraform file (`main.tf`):

    ```hcl
    provider "helm" {
      kubernetes {
        config_path = "~/.kube/config"
      }
    }

    provider "kubernetes" {
      config_path    = "~/.kube/config"
      config_context = "pi"
    }

    resource "kubernetes_namespace" "metallb" {
      metadata {
        name = "metallb"
      }
    }
    ```

2. Install the MetalLB Helm chart by adding the following configuration to your Terraform file (`main.tf`):

    ```hcl
    resource "helm_release" "metal_lb" {
      name       = "metallb"
      repository = "https://metallb.github.io/metallb"
      chart      = "metallb"
      namespace  = kubernetes_namespace.metallb.metadata[0].name

      set {
        name  = "labels.pod-security.kubernetes\\.io/enforce"
        value = "privileged"
      }

      set {
        name  = "labels.pod-security.kubernetes\\.io/audit"
        value = "privileged"
      }

      set {
        name  = "labels.pod-security.kubernetes\\.io/warn"
        value = "privileged"
      }

      set {
        name  = "speaker.secretName"
        value = "memberlist"
      }
    }
    ```

3. Create a file named `metal-lb-config.yaml` on your local machine and copy the following YAML configuration into it:

    ```yaml
    ---
    # Metallb address pool
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool
    metadata:
      name: ip-pool
      namespace: metallb
    spec:
      addresses:
        - 192.168.1.180-192.168.1.240
    ---
    # L2 configuration
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement
    metadata:
      name: l2-advert
      namespace: metallb
    spec:
      ipAddressPools:
        - ip-pool
    ```

4. Add the following Terraform configurations to your `main.tf` file to deploy the `metal-lb-config.yaml` file as Kubernetes manifests:

    ```hcl
    data "kubectl_file_documents" "metal_lb" {
      content = file("metal-lb-config.yaml")
    }

    resource "kubectl_manifest" "metal_lb" {
      for_each  = data.kubectl_file_documents.metal_lb.manifests
      yaml_body = each.value
    }
    ```

5. Now lets test our deployment, Create a file named `nginx-deployment.yaml` on your local machine and copy the following YAML configuration into it:

    ```yaml
   apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx
    spec:
      selector:
        matchLabels:
          app: nginx
      template:
        metadata:
          labels:
            app: nginx
        spec:
          containers:
            - name: nginx
              image: nginx:1
              ports:
                - name: http
                  containerPort: 80
    ---
    apiVersion: v1
    kind: Service
    metadata:
      name: nginx
    spec:
      ports:
        - name: http
          port: 80
          protocol: TCP
          targetPort: 80
      selector:
        app: nginx
      type: LoadBalancer
   ```
6. Add the following Terraform configurations to a new file called `test-deployment.tf` file to deploy the `nginx-deployment.yaml` file as Kubernetes manifests:

    ```hcl
    data "kubectl_file_documents" "test-deployment" {
    content = file("test-deployment.yaml")
    }
    
    resource "kubectl_manifest" "test-deployment" {
    for_each  = data.kubectl_file_documents.test-deployment.manifests
    yaml_body = each.value
    }
    ```
7. Run ``kubectl get svc nginx`` should show you the nginx service with an external Ip to access the instance
    ``` typescript
    kubecl get svc nginx
    NAME    TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)        AGE
    nginx   LoadBalancer   10.43.217.91   192.168.1.181   80:30415/TCP   48m

   ```