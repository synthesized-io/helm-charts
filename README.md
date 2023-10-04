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
* `API_PUBLIC_HOST` - hostname on which Governor will be used, e. g. localhost or example.com
* `JUPYTER_NOTEBOOK_PUBLIC_HOST` - hostname for Jupyter. Typically, it's `jupyter` subdomain of `API_PUBLIC_HOST`

In order to install Governor on Kubernetes, run:

```shell
helm install governor ./governor
```