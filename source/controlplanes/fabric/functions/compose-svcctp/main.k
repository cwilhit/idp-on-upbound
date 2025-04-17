
import models.io.crossplane.kubernetes.v1alpha1 as kubernetesv1alpha1
import models.io.crossplane.kubernetes.v1alpha2 as kubernetesv1alpha2
import models.io.upbound.dev.meta.v1alpha1 as metav1alpha1
import models.io.upbound.idp.bootstrap.v1alpha1 as bootstrapv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
er = option("params")?.extraResources

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

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

# We need to resolve the serviceProvideRef to confirm they've onboarded to the platform. 
# This is skipped for now and we its valud
controlplane = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.labels['crossplane.io/claim-name'] + "-ctp")
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

argoApp = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.labels['crossplane.io/claim-name'] + "-argoapp")
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
                name: oxr.metadata.labels['crossplane.io/claim-name']
                namespace: "default"
            }
        }
    }
    spec.providerConfigRef.name: "default"
}

_items = [
    providerConfigs,
    controlplane,
    argoApp,
    conditions
]
items = _items
