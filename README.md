# IDP on Upbound Reference Platform

This repository contains a reference platform for an Internal Developer Platform on [Upbound](https://www.upbound.io/product/upbound), powered by [Crossplane](https://crossplane.io).

> [!IMPORTANT]
> This platform uses _control plane topologies_, a [private preview feature set](https://docs.upbound.io/deploy/control-plane-topologies/) available only on Upbound. You can't deploy your own instance of this repository's contents unless you have these features enabled.

## Overview

This platform defines a set of APIs for a variety of cloud resources app developers might use as part of their day-to-day work:

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

## Questions?

For any questions, thoughts and comments don't hesitate to [reach
out](https://www.upbound.io/contact) or drop by
[slack.crossplane.io](https://slack.crossplane.io), and say hi.
