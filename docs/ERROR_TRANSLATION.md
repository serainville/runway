# Error Translation

Runway should translate Kubernetes failure states into app-centric explanations.

| Signal | User-facing explanation |
|---|---|
| ImagePullBackOff | The platform could not pull the application image. Check build output or registry credentials. |
| CrashLoopBackOff | The application starts and exits repeatedly. Check startup logs. |
| OOMKilled | The application exceeded its memory limit. Increase the process size or reduce memory usage. |
| Readiness probe failed | The app is running but not healthy. Check the health endpoint and startup logs. |
| CreateContainerConfigError | A required config var or secret may be missing. |
| FailedScheduling | The cluster could not place the app. Capacity or resource settings may be the issue. |
| Forbidden | A platform policy or permission blocked the deployment. |
