# OKD Machine OS

This respository contains the components necessary to build a Fedora CoreOS based OKD node. The process involves creating a container that incorporates the latest developer release of Fedora CoreOS, the OpenShift cluster artifacts, the Machine Controller Daemon, and various container overlays specific to OKD. To better understand the various components, please see the following resources:

* [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/) 
* [Machine Config Operator](https://github.com/openshift/machine-config-operator)
* [CoreOS Assembler](https://github.com/coreos/coreos-assembler)
* [cri-o](https://cri-o.io)
