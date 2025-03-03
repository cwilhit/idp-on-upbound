
import models.io.nop.v1alpha1 as nopv1alpha1
import models.io.upbound.idp.networking.v1alpha1 as networkingv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.upbound.v1alpha1 as upboundv1alpha1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = networkingv1alpha1.NetworkingIdpUpboundIoV1alpha1NetworkSpecParameters { **oxr.spec.parameters }

_metadata = lambda name: str -> any {
    { 
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = "${oxr.metadata.name}-${name}"
    }
}

_items = [nopv1alpha1.NopResource {
    metadata: _metadata('network')
    spec.forProvider = {
        fields: parameters
        conditionAfter = [{
            time: "5s"
            conditionStatus: "True"
            conditionType: "Ready"
        }]
    }
}]

_subnets = [upboundv1alpha1.ReferencedObject {
    metadata: _metadata("${snet.subnetRef.name}-${i}-obj")
    spec = {
        managementPolicies = [
            "Observe", "Create", "Delete"
        ]
        deletionPolicy: "Orphan"
        composite = {
            apiVersion: "networking.idp.upbound.io/v1alpha1"
            jsonPath: ".spec.parameters.subnets.items.subnetRef"
            kind: "Network"
            name: oxr.metadata.name
        }
        forProvider.manifest = networkingv1alpha1.SubnetClaim {
            metadata: _metadata("${snet.subnetRef.name}-${i}")
            spec.parameters = networkingv1alpha1.NetworkingIdpUpboundIoV1alpha1SubnetClaimSpecParameters{**snet.parameters} 
        }
    }
} for i, snet in parameters.subnets]

items = _items + _subnets
