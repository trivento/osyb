# osyb

OpenShift YAML Backup (OSYB) is based on [kube-backup][1]. Differences:

* cluster-reader clusterrole permissions
* runs in an osyb project instead of kube-system
* backs up OpenShift clusters that have been changed by using the UI or
  [oc][1] command

The rationale for creating OSYB is that the output of kube-backup in
conjunction with OpenShift, deviates and OpenShift has some other API resources
that are not backed up by kubectl like routes and imagestreams.

[1]: https://github.com/pieterlange/kube-backup
