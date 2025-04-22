
import models.io.upbound.idp.ai.v1alpha1 as aiv1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.nop.v1alpha1 as nopv1alpha1
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

parameters = aiv1alpha1.AiIdpUpboundIoV1alpha1ModelSpecParameters { **oxr.spec.parameters }
_items = [nopv1alpha1.NopResource {
    metadata: _metadata('ai-model')
    spec.forProvider = {
        fields = {
            modelName: parameters.model.name
            modelPath: parameters.model.path
        }
        conditionAfter = [{
            time: "5s"
            conditionStatus: "True"
            conditionType: "Ready"
        }]
    }
}]

_dxr = {
    **_dxr
    status = {
        deployedOnto: _ocds["cluster-ref"]?.Resource?.status?.atProvider?.manifest?.metadata?.uid or "None"
    }
}

_clusterRef = upboundv1alpha1.ReferencedObject {
    metadata: _metadata("cluster-ref")
    spec = {
        managementPolicies = [
            "Observe"
        ]
        deletionPolicy: "Orphan"
        composite = {
            apiVersion: "ai.idp.upbound.io/v1alpha1"
            jsonPath: ".spec.parameters.clusterRef"
            kind: "Model"
            name: oxr.metadata.name
        }
    }
}

items = _items + [_clusterRef, _dxr]