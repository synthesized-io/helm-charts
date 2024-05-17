# How to release

Update the version of the chart in `Chart.yaml` file!

```shell
helm registry login synthesizedio.jfrog.io
```

Provide your username and password.

```
helm package  charts/governor
```

This will create a packaged tgz file.

```
helm push governor-x.x.x.tgz oci://synthesizedio.jfrog.io/helm
```
