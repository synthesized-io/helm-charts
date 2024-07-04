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

More details about installation can be found [here](https://docs.synthesized.io/governor/latest/deployment/helm)

In order to install Governor on Kubernetes, run:

```shell
helm install governor ./governor
```

### Self-hosted vs SaaS mode

This Helm chart provides options for both saas and self-hosted installation, defaulting to self-hosted. 
The mode is controlled by `mode` value.

#### SaaS mode
* Director service, configmap, secrets and deployment are being installed.
* API is configured to use the director.
* Frontend is configured to use "cloud" mode via `UI_ENVIRONMENT` variable.
* Posthog is configured via `UI_POSTHOG_ANALYTICS_API_HOST` variable.
* `GOVERNOR_SECURITY_OWNERACCESSONLY` variable is enabled for backend.

#### Self-hosted mode

* Director service, configmap, secrets, deployment are not installed
* Frontend is configured to use "on-premise" mode via `UI_ENVIRONMENT` variable

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
