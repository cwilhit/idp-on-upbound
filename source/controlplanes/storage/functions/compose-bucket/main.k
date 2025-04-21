
import models.io.upbound.idp.storage.v1alpha1 as storagev1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1
import models.io.nop.v1alpha1 as nopv1alpha1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = storagev1alpha1.StorageIdpUpboundIoV1alpha1BucketSpecParameters { **oxr.spec.parameters }
_useless = ""
_metadata = lambda name: str -> any {
    { 
        annotations = { "krm.kcl.dev/composition-resource-name" = name }
        name = "${oxr.metadata.name}-${name}"
    }
}

_items = [nopv1alpha1.NopResource {
    metadata: _metadata('bucket')
    spec.forProvider = {
        fields: parameters
        conditionAfter = [{
            time: "5s"
            conditionStatus: "True"
            conditionType: "Ready"
        }]
    }
}]
items = _items
