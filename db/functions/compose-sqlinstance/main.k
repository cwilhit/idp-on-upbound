
import models.io.upbound.idp.db.v1alpha1 as dbv1alpha1
import models.io.nop.v1alpha1 as nopv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.upbound.v1alpha1 as upboundv1alpha1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources

_metadata = lambda name: str -> any {
    { 
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = "${oxr.metadata.name}-${name}"
    }
}
parameters = dbv1alpha1.DbIdpUpboundIoV1alpha1SQLInstanceClaimSpecParameters { **oxr.spec.parameters }

_items = [nopv1alpha1.NopResource {
    metadata: _metadata('sql-instance')
    spec.forProvider = {
        fields: parameters
        fields.subnetPlacement: _ocds["${oxr.metadata.name}-network-ref"]?.Resource?.status?.atProvider?.manifest?.metadata?.uid or "None"
        conditionAfter = [{
            time: "5s"
            conditionStatus: "True"
            conditionType: "Ready"
        }]
    }
}]

_secret = upboundv1alpha1.ReferencedObject {
    metadata: _metadata("sql-instance-secret-obj")
    spec = {
        managementPolicies = [
            "*"
        ]
        deletionPolicy: "Delete"
        ownerPolicy: "OnCreate"
        composite = {
            apiVersion: "db.idp.upbound.io/v1alpha1"
            jsonPath: ".spec.parameters.password.passwordSecretRef"
            kind: "SQLInstance"
            name: oxr.metadata.name
        }
        forProvider.manifest = {
            kind: "Secret"
            apiVersion: "v1"
            metadata.name: parameters.password.passwordSecretRef.name
            metadata.namespace: "default"
            stringData = {
                password: "booyah"
            }
        }
    }
}

_networkRef = upboundv1alpha1.ReferencedObject {
    metadata: _metadata("network-ref")
    spec = {
        managementPolicies = [
            "Observe"
        ]
        deletionPolicy: "Orphan"
        composite = {
            apiVersion: "db.idp.upbound.io/v1alpha1"
            jsonPath: ".spec.parameters.networkRef"
            kind: "SQLInstance"
            name: oxr.metadata.name
        }
        # forProvider.manifest = {
        #    kind: "NetworkClaim"
        #    apiVersion: "networking.idp.upbound.io/v1alpha1"
        #    metadata.name: parameters.networkRef.name
        #}
    }
}

items = _items + [_secret, _networkRef]
