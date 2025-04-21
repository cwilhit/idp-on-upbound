
import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.idp.bootstrap.v1alpha1 as bootstrapv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import base64

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = bootstrapv1alpha1.BootstrapIdpUpboundIoV1alpha1PlatformPortalSpecParameters {**oxr.spec.parameters}

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_status = {}
_kubeconfig = None
_identitySecret = None
clusterSecretMissing = not (parameters.cluster.clusterSecretRef)
if _ocds["${oxr.metadata.name}-kubeconfig"]?.Resource?.status?.atProvider?.data:
    _kubeconfig = _ocds["${oxr.metadata.name}-kubeconfig"]?.Resource?.status?.atProvider?.data["${parameters.cluster.clusterSecretRef.key}"]
if _ocds["${oxr.metadata.name}-id"]?.Resource?.status?.atProvider?.data:
    _identitySecret = _ocds["${oxr.metadata.name}-id"]?.Resource?.status?.atProvider?.data["${parameters.cluster.identity.secretRef.key}"]

if clusterSecretMissing:
    _status = {
        type: "ServiceProviderReady"
        status: "False"
        reason: "FailedToCreate"
        message: "A secret containing a kubeconfig is required."
    }
elif not _kubeconfig:
    _status = {
        type: "ServiceProviderReady"
        status: "False"
        reason: "FailedToCreate"
        message: "No kubeconfig was found at the provided secret key"
    }
elif not _identitySecret:
    _status = {
        type: "ServiceProviderReady"
        status: "False"
        reason: "FailedToCreate"
        message: "No identity was found at the provided secret key"
    }

conditions = {
    apiVersion: "meta.krm.kcl.dev/v1alpha1"
    kind: "Conditions"
    conditions = [{
        target: "Composite"
        force: False
        condition = _status
    }]
}

clusterSecretRef = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-kubeconfig")
    metadata.name = "${oxr.metadata.name}-kubeconfig"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: parameters.cluster.clusterSecretRef.name
            namespace: parameters.cluster.clusterSecretRef.namespace
            annotations = {
                "crossplane.io/external-name": parameters.cluster.clusterSecretRef.name
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

identitySecretRef = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-id")
    metadata.name = "${oxr.metadata.name}-id"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: parameters.cluster.identity.secretRef.name
            namespace: parameters.cluster.identity.secretRef.namespace
            annotations = {
                "crossplane.io/external-name": parameters.cluster.identity.secretRef.name
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

portalCtpServerSecretRef = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-sref1")
    metadata.name = "${oxr.metadata.name}-sref1"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: parameters.portalControlPlane.serverSecretRef.name
            namespace: parameters.portalControlPlane.serverSecretRef.namespace
            annotations = {
                "crossplane.io/external-name": parameters.portalControlPlane.serverSecretRef.name
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

portalCtpCaSecretRef = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-sref2")
    metadata.name = "${oxr.metadata.name}-sref2"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: parameters.portalControlPlane.caDataSecretRef.name
            namespace: parameters.portalControlPlane.caDataSecretRef.namespace
            annotations = {
                "crossplane.io/external-name": parameters.portalControlPlane.caDataSecretRef.name
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

portalCtpSaSecretRef = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-sref3")
    metadata.name = "${oxr.metadata.name}-sref3"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: parameters.portalControlPlane.serviceAccountRef.name
            namespace: parameters.portalControlPlane.serviceAccountRef.namespace
            annotations = {
                "crossplane.io/external-name": parameters.portalControlPlane.serviceAccountRef.name
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

providerConfig = kubernetesv1alpha1.ProviderConfig {
    metadata = _metadata("${oxr.metadata.name}-providerconfig")
    metadata.name = "${oxr.metadata.name}-providerconfig"
    spec.credentials = {
        secretRef = {**parameters.cluster.clusterSecretRef}
        source = "Secret"
    }
    spec.identity = {
        type: parameters.cluster.identity.type
        source: "Secret"
        secretRef = {**parameters.cluster.identity.secretRef}
    }
}

backstageNamespace = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-ns")
    metadata.name = "${oxr.metadata.name}-ns"
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Namespace"
        metadata = {
            name: "${oxr.metadata.name}-backstage"
        }
    }
    spec.providerConfigRef.name: "${oxr.metadata.name}-providerconfig"
}

_server = None
if _ocds["${oxr.metadata.name}-sref1"]?.Resource?.status?.atProvider?.manifest?.data:
    _server = base64.decode(_ocds["${oxr.metadata.name}-sref1"]?.Resource?.status?.atProvider?.manifest?.data["${parameters.portalControlPlane.serverSecretRef.key}"])
_caData = None
if _ocds["${oxr.metadata.name}-sref2"]?.Resource?.status?.atProvider?.manifest?.data:
    _caData = base64.decode(_ocds["${oxr.metadata.name}-sref2"]?.Resource?.status?.atProvider?.manifest?.data["${parameters.portalControlPlane.caDataSecretRef.key}"])
_saToken = None
if _ocds["${oxr.metadata.name}-sref3"]?.Resource?.status?.atProvider?.manifest?.data:
    _saToken = base64.decode(_ocds["${oxr.metadata.name}-sref3"]?.Resource?.status?.atProvider?.manifest?.data["${parameters.portalControlPlane.serviceAccountRef.key}"])

backstageDeployment = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-backstage")
    metadata.name = "${oxr.metadata.name}-backstage"
    spec.forProvider.manifest = {
        apiVersion: "apps/v1"
        kind: "Deployment"
        metadata = {
            name: "${oxr.metadata.name}-backstage"
            namespace: "${oxr.metadata.name}-backstage"
        }
        spec = {
            replicas: 1
            selector: {
                matchLabels: {
                    app: "backstage"
                }
            }
            template = {
                metadata: {
                    labels: {
                        app: "backstage"
                    }
                }
                spec.containers = [{
                    name: "backstage"
                    image: "${parameters.portalConfig.backstage.image.repository}:${parameters.portalConfig.backstage.image.tag}"
                    imagePullPolicy: "IfNotPresent"
                    ports = [{
                        name: "http"
                        containerPort: 7007
                    }]
                    env = [{
                        name: "BACKSTAGE_HOST"
                        value: "http://${parameters.portalConfig.backstage.ingress.host}"
                    }, {
                        name: "DB_HOST"
                        value: "${oxr.metadata.name}-db-rw"
                    }, {
                        name: "PORTAL_CONTROL_PLANE_URL"
                        value: _server
                    }, {
                        name: "PORTAL_CONTROL_PLANE_NAME"
                        value: "portal"
                    }, {
                        name: "PORTAL_CONTROL_PLANE_SA"
                        value: _saToken
                    }, {
                        name: "PORTAL_CONTROL_PLANE_CA_DATA"
                        value: _caData
                    }]
                    envFrom = [{
                        secretRef.name: "${oxr.metadata.name}-db-superuser"
                    }]
                    command = ["node", "packages/backend", "--config", "app-config.yaml"]
                }]
            }
        }
    }
    spec.providerConfigRef.name: "${oxr.metadata.name}-providerconfig"
}

backstageIngress = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-ingress")
    metadata.name = "${oxr.metadata.name}-ingress"
    spec.forProvider.manifest = {
        apiVersion: "networking.k8s.io/v1"
        kind: "Ingress"
        metadata = {
            name: "${oxr.metadata.name}-ingress"
            namespace: "${oxr.metadata.name}-backstage"
        }
        spec = {
            ingressClassName: "ing"
            rules = [{
                host: "80"
                http.paths = [{
                    path: "/"
                    pathType: "ImplementationSpecific"
                    backend.service = {
                        name: "${oxr.metadata.name}-backstage"
                        port.number: 80
                    }
                }]
            }]
        }
    }
    spec.providerConfigRef.name: "${oxr.metadata.name}-providerconfig"
}

backstageService = kubernetesv1alpha2.Object {
    metadata = _metadata("${oxr.metadata.name}-svc")
    metadata.name = "${oxr.metadata.name}-svc"
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Service"
        metadata = {
            name: "${oxr.metadata.name}-svc"
            namespace: "${oxr.metadata.name}-backstage"
        }
        spec = {
            type: "ClusterIP"
            ports = [{
                port: 80
                targetPort: "http"
                name: "http"
            }]
            selector: {
                app: "backstage"
            }
        }
    }
    spec.providerConfigRef.name: "${oxr.metadata.name}-providerconfig"
}

_backstageDatabase = None

if parameters.portalConfig.backstage.db.incluster.enabled:
    _backstageDatabase = kubernetesv1alpha2.Object {
        metadata = _metadata("${oxr.metadata.name}-db")
        metadata.name = "${oxr.metadata.name}-db"
        spec.forProvider.manifest = {
            apiVersion: "postgresql.cnpg.io/v1"
            kind: "Cluster"
            metadata = {
                name: "${oxr.metadata.name}-db"
                namespace: "${oxr.metadata.name}-backstage"
            }
            spec = {
                instances: parameters.portalConfig.backstage.db.instances
                storage.size: "1Gi"
                enableSuperuserAccess: True
            }
        }
        spec.providerConfigRef.name: "${oxr.metadata.name}-providerconfig"
    }

_items = [
    clusterSecretRef,
    identitySecretRef,
    portalCtpServerSecretRef,
    portalCtpCaSecretRef,
    portalCtpSaSecretRef,
    providerConfig,
    backstageNamespace,
    backstageDeployment,
    backstageIngress,
    backstageService,
    _backstageDatabase,
    conditions
]
items = _items