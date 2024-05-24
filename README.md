# Synthesized Helm Charts

Synthesized applications ready to launch on Kubernetes using Kubernetes [Helm](https://github.com/helm/helm).

## SDK

Installs Synthesized [SDK](https://docs.synthesized.io/sdk/latest/)

## TDK

Installs Synthesized [TDK](https://docs.synthesized.io/tdk/latest/)

## Governor

Installs [Governor](https://docs.synthesized.io/governor/latest/)

The following configuration values should be updated:

* `SPRING_DATASOURCE_URL` - JDBC URL to Governor PostgreSQL database
* `SPRING_DATASOURCE_USERNAME` - database username
* `SPRING_DATASOURCE_PASSWORD` - database password
* `JWT_SECRET` - JWT secret for authentication
* `SYNTHESIZED_KEY` - licence key
* `API_PUBLIC_HOST` - hostname on which Governor will be used, e. g. localhost or example.com
* `JUPYTER_NOTEBOOK_PUBLIC_HOST` - hostname for Jupyter. Typically, it's `jupyter` subdomain of `API_PUBLIC_HOST`

More details about installation can be found [here](https://docs.synthesized.io/governor/latest/deployment/helm)

In order to install Governor on Kubernetes, run:

```shell
helm install governor ./governor
```

### How to release Governor Helm

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
