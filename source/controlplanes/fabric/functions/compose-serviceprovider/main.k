
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

# Make a new control plane group when onboarding a new service provider
serviceProviderGroup = {
    apiVersion: "kubernetes.crossplane.io/v1alpha2"
    kind: "Object"
    metadata = _metadata(oxr.metadata.labels['crossplane.io/claim-name'] + "-group")
    spec.forProvider.manifest = {
        apiVersion: "v1"
        kind: "Namespace"
        metadata = {
            name: oxr.metadata.labels['crossplane.io/claim-name']
            labels = {
                "spaces.upbound.io/group": "true"
            }
        }
        spec: {}
    }
    spec.providerConfigRef.name: "space"
}

_items = [
    providerConfigs,
    serviceProviderGroup,
    conditions
]
items = _items
