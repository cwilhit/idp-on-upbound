
import models.io.upbound.idp.compute.v1alpha1 as computev1alpha1
import models.io.upbound.idp.iam.v1alpha1 as iamv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.nop.v1alpha1 as nopv1alpha1
import models.io.upbound.v1alpha1 as upboundv1alpha1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = computev1alpha1.ComputeIdpUpboundIoV1alpha1ClusterSpecParameters { **oxr.spec.parameters }

_metadata = lambda name: str -> any {
    { 
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = "${oxr.metadata.name}-${name}"
    }
}

_items = [nopv1alpha1.NopResource {
    metadata: _metadata('cluster')
    spec.forProvider = {
        fields: parameters
        conditionAfter = [{
            time: "5s"
            conditionStatus: "True"
            conditionType: "Ready"
        }]
    }
}]

_networkRef = upboundv1alpha1.ReferencedObject {
    metadata: _metadata("network-ref")
    spec = {
        managementPolicies = [
            "Observe"
        ]
        deletionPolicy: "Orphan"
        composite = {
            apiVersion: "compute.idp.upbound.io/v1alpha1"
            jsonPath: ".spec.parameters.networkRef"
            kind: "Cluster"
            name: oxr.metadata.name
        }
    }
}

_saRef = upboundv1alpha1.ReferencedObject {
    metadata: _metadata("sa-ref")
    spec = {
        managementPolicies = [
            "*"
        ]
        deletionPolicy: "Delete"
        composite = {
            apiVersion: "compute.idp.upbound.io/v1alpha1"
            jsonPath: ".spec.parameters.serviceAccountRef"
            kind: "Cluster"
            name: oxr.metadata.name
        }
        forProvider.manifest = iamv1alpha1.ServiceAccountClaim {
            metadata.name = parameters.serviceAccountRef.name
            spec.parameters = {
                billingAccount: "123456"
            }
        }
    }
}

items = _items + [_networkRef, _saRef]
