
import models.io.nop.v1alpha1 as nopv1alpha1
import models.io.upbound.idp.compute.v1alpha1 as computev1alpha1
import models.k8s.apimachinery.pkg.apis.meta.v1 as metav1

oxr = option("params").oxr # observed composite resource
_ocds = option("params").ocds # observed composed resources
_dxr = option("params").dxr # desired composite resource
dcds = option("params").dcds # desired composed resources
parameters = computev1alpha1.ComputeIdpUpboundIoV1alpha1VirtualMachineSpecParameters { **oxr.spec.parameters }

_metadata = lambda name: str -> any {
    { annotations = { "krm.kcl.dev/composition-resource-name" = name }}
}

_items = [nopv1alpha1.NopResource {
    metadata: _metadata('virtual-machine')
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
