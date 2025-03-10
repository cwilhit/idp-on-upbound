# IDP on Upbound Reference Platform

This repository contains a reference platform for an Internal Developer Platform on [Upbound](https://www.upbound.io/product/upbound), powered by [Crossplane](https://crossplane.io).

> [!IMPORTANT]
> This platform uses _control plane topologies_, a [private preview feature set](https://docs.upbound.io/deploy/control-plane-topologies/) available only on Upbound. You can't deploy your own instance of this repository's contents unless you have these features enabled.

## Overview

This platform defines a set of APIs for a variety of cloud resources app developers might use as part of their day-to-day work. For ease of navigability, this reference architecture is defined as a monorepo, composed of several [control plane projects](https://docs.upbound.io/learn/core-concepts/projects/):

* [compute](compute/) is a control plane project that defines the following APIs:
  * [Application](compute/apis/applications/definition.yaml) lets a developer deploy a basic containerized app onto a Kubernetes cluster.
  * [Cluster](compute/apis/clusters/definition.yaml) lets a developer spin up a new Kubernetes Cluster with its own service account inside a Network.
  * [Function](compute/apis/functions/definition.yaml) lets a developer deploy a serverless function. 
  * [VirtualMachine](compute/apis/virtualmachines/definition.yaml) lets a developer deploy a Virtual Machine.
* [networking](networking/) is a control plane project that defines the following APIs:
  * [Network](networking/apis/networks/definition.yaml) lets a developer deploy a new VPC.
  * [Subnet](networking/apis/subnets/definition.yaml) lets a developer deploy a subnet in a VPC.
* [iam](iam/) is a control plane project that defines the following APIs:
  * [Account](iam/apis/accounts/definition.yaml) lets a developer deploy a new Cloud account.
  * [ServiceAccount](iam/apis/serviceaccounts/definition.yaml) lets a developer deploy a Service Account.
* [db](db/) is a control plane project that defines the following APIs:
  * [SQLInstance](db/apis/sqlinstances/definition.yaml) lets a developer deploy a SQL Instance into a VPC subnet.
* [storage](storage/) is a control plane project that defines the following APIs:
  * [bucket](storage/apis/buckets/definition.yaml) lets a developer deploy a basic bucket.
* [ai](ai/) is a control plane project that defines the following APIs:
  * [Model](ai/apis/models/definition.yaml) lets a developer deploy an AI Model to a Kubernetes cluster.

The composite types linked above are meant to illustrate how to use the [control plane topology](https://docs.upbound.io/deploy/control-plane-topologies/) features. These composites compose:

* [_NopResources_](https://github.com/crossplane-contrib/provider-nop), a mock resource type that mimics deploying real cloud resources.
* [_ReferencedObjects_](https://docs.upbound.io/deploy/control-plane-topologies/#compose-a-_referencedobject_), an Upbound-only resource type that lets you reference, observe, and potentially create resources defined by APIs offered by other **service-level control planes** powering your platform.

> [!TIP]
> For ease of navigability, this reference architecture is defined as a monorepo. You don't have to do it this way and have flexibility to define each part in its own repo if you wish.

## Architecture

This platform defines a two-tier topology of control planes that work together to provide a unified experience for platform consumers:

* **platform control planes:** There's only one platform control plane deployed in this reference architecture. You can find it's definition in the [platform](platform/) folder. All API requests made by consumers flows through this control plane to lower-level control planes.
* **service-level control planes:** Individual platform teams own service-level control planes. They define a part of the total APIs offered on the platform. The platform control plane routes all requests to service-level control planes. This reference architecture deploys a control plane on a domain boundary:
  * [compute](compute/examples/ctp.yaml)
  * [networking](networking/examples/ctp.yaml)
  * [iam](iam/examples/ctp.yaml)
  * [db](db/examples/ctp.yaml)
  * [storage](storage/examples/ctp.yaml)
  * [ai](ai/examples/ctp.yaml)

Each link above is to the definition of the control plane resource deployed with the corresponding project it's defined next to. 

The single **platform control plane** is defined [here](platform/examples/ctp.yaml). It doesn't define any of its own APIs. Instead, each API set defined by each service-level control plane gets deployed to the platform control plane as [RemoteConfigurations](https://docs.upbound.io/deploy/control-plane-topologies/#install-a-_remoteconfiguration_). This list of API dependencies is defined [here](platform/examples/remote-configs.yaml).

Once all control planes get deployed, create an [Environment](https://docs.upbound.io/deploy/control-plane-topologies/#use-an-_environment_-to-route-resources) to configure how resources get routed to service-level control planes. This reference architecture employs a [basic routing scheme](platform/examples/environment.yaml) to map API groups to their corresponding service-level control planes 1:1.

## Quickstart

### Prerequisites

Before you can deploy the reference platform you should install the `up` CLI.

To install `up` run this install script:

```console
curl -sL https://cli.upbound.io | sh
```

See [up docs](https://docs.upbound.io/cli/) for more install options.

To install `crossplane` CLI follow https://docs.crossplane.io/latest/cli/#installing-the-cli

### Deploy the infrastructure

Clone this repository to your machine and change your current directory to its root. Then, log on to Upbound:

```console
up login
```

Connect to a Cloud Space in Upbound where the _Topologies_ private preview feature is enabled:

```console
up ctx upbound/upbound-gcp-us-central-1-preview/default
```

Deploy each service-level control plane. A sample resource configuration is linked in the previous section:

```console
kubectl apply -f compute/examples/ctp.yaml \
  -f storage/examples/ctp.yaml \
  -f networking/examples/ctp.yaml \
  -f iam/examples/ctp.yaml \
  -f db/examples/ctp.yaml \
  -f ai/examples/ctp.yaml
```

Once each control plane becomes healthy, connect to it and install the corresponding configuration built from its control plane project:

```console
up ctx ./compute
crossplane xpkg install configuration xpkg.upbound.io/upbound/idp-compute:v0.0.0-1741555865

up ctx ../storage
crossplane xpkg install configuration xpkg.upbound.io/upbound/idp-storage:v0.0.0-1741489092

up ctx ../networking
crossplane xpkg install configuration xpkg.upbound.io/upbound/idp-networking:v0.0.0-1741442021

up ctx ../db
crossplane xpkg install configuration xpkg.upbound.io/upbound/idp-db:v0.0.0-1741552381

up ctx ../iam
crossplane xpkg install configuration xpkg.upbound.io/upbound/idp-iam:v0.0.0-1741553829

up ctx ../ai
crossplane xpkg install configuration xpkg.upbound.io/upbound/idp-ai:v0.0.0-1741550279
```

Deploy the platform control plane:

```console
up ctx ..
kubectl apply -f platform/examples/ctp.yaml
```

Configure the platform control plane with Remote Configurations and routing:

```
up ctx ./portal
kubectl apply -f platform/examples/remote-configs.yaml \
  -f environment.yaml
```

### Deploy example resources

Each control plane project contains example manifests for resource claims. Deploy these to the platform control plane (portal) and watch how they get routed and created on lower-level control planes.

## Questions?

For any questions, thoughts and comments don't hesitate to [reach
out](https://www.upbound.io/contact) or drop by
[slack.crossplane.io](https://slack.crossplane.io), and say hi.
