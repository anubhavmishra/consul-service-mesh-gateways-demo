# HashiCorp Consul Service Mesh - Multi Cloud

Terraform config to create multiple Consul datacenters in Azure Kubernetes Service (AKS), DigitalOcean Kubernetes Service, and VMs on Azure to showcase Multi-Cloud and L7 Features in Consul

![](/images/consul-service-mesh-gateway-multi-cloud-picture.png)

The three datacenters are federated together and service traffic is routed using Consul Gateways.

Terraform Version: 0.12.7 +

**Note: This project is not production ready and is meant to showcase HashiCorp Consul's Service Mesh features.**

## Environment variables

Before running `terraform plan` or `apply` configure the following environment variables to allow Terraform
to make API calls to Azure and DigitalOcean.

```
export ARM_CLIENT_ID="xxx-xxx-x-x-x-x-x-xxxx-"
export ARM_CLIENT_SECRET="x-x-x-xxxx--xxx--x-x-xx"
export ARM_SUBSCRIPTION_ID="xx-x--xx-xxx-xxx-x-x"
export ARM_TENANT_ID="xxx-xx-xx-x"

export TF_VAR_digitalocean_token="abcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefghabcdefgh"
export TF_VAR_client_id="${ARM_CLIENT_ID}"
export TF_VAR_client_secret="${ARM_CLIENT_SECRET}"
```

## Creating infrastructure

Run `terraform plan`.

```bash
terraform plan

Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

data.google_project.project: Refreshing state...
data.google_dns_managed_zone.livedemos_xyz: Refreshing state...

------------------------------------------------------------------------


.....

Plan: 40 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.
```

Run `terraform apply` to create the infrastructure. This operation will take about 10-12 mins.

Expected output.

```bash
Apply complete! Resources: x added, 2 changed, 0 destroyed.

Outputs:

aks_consul_addr = 13.71.118.185
aks_consul_gateway_addr = 104.211.245.65
aks_web_addr = 104.211.219.93
digitalocean_consul_addr = 68.183.245.35
digitalocean_consul_gateway_addr = 68.183.245.24
k8s_config_aks = apiVersion: v1
clusters:
- cluster:

.....
```

## Accessing the web service using the browser

```bash
open http://$(terraform output aks_web_addr)
```

## Output variables

The Terraform output variables contain the details of the various loadbalancers, public IP addresses and Kubernetes config which can be
used to access the system.

```
$ terraform output

k8s_config = apiVersion: v1
clusters:
- cluster:
#...
vms_consul_gateway_addr = 13.64.246.61
vms_consul_server_addr = 13.64.245.65
vms_pong_addr = 13.64.245.34
vms_private_key = -----BEGIN RSA PRIVATE KEY-----
MIIJKQIBAAKCAgEA2qokNUFCSDCgf5DdUTSRE20UF/VzNtNE9J2N1QUrZFcjGXj4
#...
```

## SMI Controller

This configuration will automatically deploy the Consul SMI controller however in order to interact with it the custom CRDs and the policy must be applied with `kubectl`.

First apply the CRDS:

```
$ kubectl apply -f crds.yml
customresourcedefinition.apiextensions.k8s.io/traffictargets.access.smi-spec.io created
customresourcedefinition.apiextensions.k8s.io/httproutegroups.specs.smi-spec.io created
customresourcedefinition.apiextensions.k8s.io/tcproutes.specs.smi-spec.io created
```

Then you can apply the Traffic Targets to allow traffic between the two Pong Servers:

```
$ kubectl apply -f policy.yml
tcproute.specs.smi-spec.io/currency created
traffictarget.access.smi-spec.io/currency-targets created
tcproute.specs.smi-spec.io/payment created
traffictarget.access.smi-spec.io/payment-targets created
```

You can check that these have been applied by looking at the Consul UI:

```
$ open "http://$(terraform output vms_consul_server_addr):8500/ui/aks/intentions"
```

## Running the app

The application can be run using curl. First fetch the endpoint ip from the kubernetes services.

```
➜ kubectl get svc
NAME                                 TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)                                                                   AGE
consul-consul-connect-injector-svc   ClusterIP      10.0.6.49     <none>           443/TCP                                                                   3m58s
consul-consul-dns                    ClusterIP      10.0.30.111   <none>           53/TCP,53/UDP                                                             3m58s
consul-consul-server                 ClusterIP      None          <none>           8500/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP,8600/TCP,8600/UDP   3m58s
consul-consul-ui                     ClusterIP      10.0.228.59   <none>           80/TCP                                                                    3m58s
consul-lb                            LoadBalancer   10.0.192.89   104.42.213.169   80:32362/TCP,8500:30709/TCP,8302:30944/TCP,8300:30177/TCP                 7m54s
gateways                             LoadBalancer   10.0.50.122   104.42.208.24    443:30866/TCP                                                             7m54s
kubernetes                           ClusterIP      10.0.0.1      <none>           443/TCP                                                                   12m
web-lb                               LoadBalancer   10.0.75.196   104.42.208.69    80:32761/TCP                                                              7m55s
```

```
➜ curl 104.42.208.69
{
  "name": "web",
  "type": "HTTP",
  "duration": "12.968804ms",
  "body": "Welcome to the service mess superstore",
  "upstream_calls": [
    {
      "name": "Payment",
      "uri": "http://localhost:9091",
      "type": "HTTP",
      "duration": "7.080423ms",
      "body": "\"payment",
      "upstream_calls": [
        {
          "name": "currency-aks",
          "uri": "http://localhost:9091",
          "type": "HTTP",
          "duration": "10.7µs",
          "body": "rate 1USD to 3GBP"
        }
      ]
    }
  ]
}
```

## Helper

There is a simple helper script which can be used to automate some of the tasks such as retrieving the K8s config or
creating SSH session to the various VMs.

```
➜ ./helper
Usage:
k8s_config            - Fetch Kubernetes config from the remote state
vm_private_key        - Fetch SSH Private key for VMS from the remote state
ssh_vm_consul_server  - Create an SSH session to the consul server
ssh_vm_consul_gateway - Create an SSH session to the consul gateway
ssh_vm_pong           - Create an SSH session to the consul gateway
```
