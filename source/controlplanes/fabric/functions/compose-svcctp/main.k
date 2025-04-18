
import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.idp.bootstrap.v1alpha1 as bootstrapv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import base64
import yaml

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
er = option("params")?.extraResources

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

# Fetch the ProviderConfigs to the Space and in-cluster control plane, since these are needed
# to create the necessary MRs. If the user didn't configure these yet, propogate that as a status
# to the claim.
providerConfigs = {
    apiVersion: "meta.krm.kcl.dev/v1alpha1"
    kind: "ExtraResources"
    requirements = {
        incluster = {
            apiVersion: "kubernetes.crossplane.io/v1alpha1",
            kind: "ProviderConfig",
            matchName: "default"
        }, 
        space = {
            apiVersion: "kubernetes.crossplane.io/v1alpha1",
            kind: "ProviderConfig",
            matchName: "space"
        }
    }
}
_status = {}
providerConfigMissing = not (er?.config or er?.space)
if providerConfigMissing:
    _status = {
        type: "ServiceProviderReady"
        status: "False"
        reason: "FailedToCreate"
        message: "A ProviderConfig for in-cluster or the Space is missing"
    }

conditions = {
    apiVersion: "meta.krm.kcl.dev/v1alpha1"
    kind: "Conditions"
    conditions = [{
        target: "CompositeAndClaim"
        force: False
        condition = _status
    }]
}

# Create the control plane requested by the service provider

# We need to resolve the serviceProvideRef to confirm they've onboarded to the platform. 
# This is skipped for now and we its valud
controlplane = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.labels['crossplane.io/claim-name'] + "-ctp")
    metadata.name = oxr.metadata.name + "-ctp"
    spec.forProvider.manifest = {
        apiVersion: "spaces.upbound.io/v1beta1"
        kind: "ControlPlane"
        metadata = {
            name: oxr.metadata.labels['crossplane.io/claim-name']
            namespace: oxr.spec.parameters.serviceProviderRef.name
        }
        spec.crossplane.autoUpgrade.channel: "Rapid"
    }
    spec.providerConfigRef.name: "space"
}

# Collect secret information from various places to build the control plane context
# kubeconfig for the control plane above, to store in a secret to be accessed by Argo CD later
_clusterSecretName = ""
_clusterSecretNamespace = ""

if er?.space:
    _clusterSecretName = er?.space[0]?.Resource?.spec?.credentials?.secretRef?.name
    _clusterSecretNamespace = er?.space[0]?.Resource?.spec?.credentials?.secretRef?.namespace

clusterConfig = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.name + "-ctp-conn1")
    metadata.name = oxr.metadata.name + "-observed-secret1"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: _clusterSecretName
            namespace: _clusterSecretNamespace
            annotations = {
                "crossplane.io/external-name": _clusterSecretName
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

_credentialName = ""
_credentialNamespace = ""
if er?.space:
    _credentialName = er?.space[0]?.Resource?.spec?.identity?.secretRef?.name
    _credentialNamespace = er?.space[0]?.Resource?.spec?.identity?.secretRef?.namespace

_kubeconfig = {}
upboundCredentials = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.name + "-ctp-conn2")
    metadata.name = oxr.metadata.name + "-observed-secret2"
    spec.managementPolicies: ["Observe"]
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: _credentialName
            namespace: _credentialNamespace
            annotations = {
                "crossplane.io/external-name": _credentialName
            }
        }
    }
    spec.providerConfigRef.name: "default"
}
if _ocds["${oxr.metadata.name}-ctp-conn1"]?.Resource?.status?.atProvider:
    _kubeconfig = yaml.decode(base64.decode(_ocds["${oxr.metadata.name}-ctp-conn1"]?.Resource?.status?.atProvider?.manifest?.data?.kubeconfig))

_server = ""
_caData = ""
_ctpName = oxr.metadata.labels['crossplane.io/claim-name'] 
_ctpGroup = oxr.spec.parameters.serviceProviderRef.name
_token = base64.decode(_ocds["${oxr.metadata.name}-ctp-conn2"]?.Resource?.status?.atProvider?.manifest?.data?.token) or ""
if _kubeconfig?.clusters:
    _server = _kubeconfig?.clusters[0]?.cluster?.server
    _caData = _kubeconfig?.clusters[0]?.cluster?['certificate-authority-data']

# This is the creation of the secret for the control plane in this composition, for Argo.
connectionSecret = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.labels['crossplane.io/claim-name'] + "-ctp-context")
    metadata.name = oxr.metadata.name + "-ctp-context"
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Secret"
        metadata = {
            name: oxr.metadata.labels['crossplane.io/claim-name'] + "-ctp-context"
            namespace: "argocd"
            labels = {
                "argocd.argoproj.io/secret-type": "cluster"
            }
        }
        type: "Opaque"
        stringData = {
            name: oxr.metadata.labels['crossplane.io/claim-name'] + "-ctp-context"
            server: "${_server}/apis/spaces.upbound.io/v1beta1/namespaces/${_ctpGroup}/controlplanes/${_ctpName}/k8s"
            config = """{
    "execProviderConfig": {
        "apiVersion": "client.authentication.k8s.io/v1",
        "command": "up",
        "args": [ "org", "token" ],
        "env": {
            "ORGANIZATION": "upbound", 
            "UP_TOKEN": "${_token}"
        }
    },
    "tlsClientConfig": {
        "insecure": false,
        "caData": "${_caData}"
    }
}"""
        }
    }
    spec.providerConfigRef.name: "default"
}

# This is the associated Argo app, pointed at the control plane created above throguh the 
# secret generated above.
argoApp = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.labels['crossplane.io/claim-name'] + "-argoapp")
    metadata.name = oxr.metadata.name + "-argoapp"
    spec.forProvider.manifest = {
        apiVersion: "argoproj.io/v1alpha1"
        kind: "Application"
        metadata = {
            name: oxr.metadata.labels['crossplane.io/claim-name']
            namespace: "argocd"
        }
        spec = {
            project: "default"
            source = {
                repoURL: "https://github.com/cwilhit/idp-on-upbound.git"
                targetRevision: "HEAD"
                path: "configuration/" + oxr.metadata.labels['crossplane.io/claim-name']
                directory.recurse: True
            }
            destination = {
                name: oxr.metadata.labels['crossplane.io/claim-name'] + "-ctp-context"
                namespace: "argocd"
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

_items = [
    providerConfigs,
    upboundCredentials,
    clusterConfig,
    connectionSecret,
    controlplane,
    argoApp,
    conditions
]
items = _items
