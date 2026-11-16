# Evidencia: Laboratorio 1.3, de Docker a Kubernetes local

| Dato | Valor |
|---|---|
| Servicio | `catalog-service` con `@Timeout`, `@Retry`, `@CircuitBreaker` y `@Fallback` (Lab 1.2) |
| Imagen | `sodasi/catalog-service:1.0.0` |
| Repositorio en Docker Hub | https://hub.docker.com/r/sodasi/catalog-service |
| Clúster | Kubernetes de Docker Desktop (nodo `docker-desktop`, v1.34.1) |
| Puerto de la aplicación | 8081 (configurado en `application.properties`) |
| Fecha | 16 de noviembre de 2026 |

> 

---

## 1. Clúster de Kubernetes operativo

```
PS> kubectl get nodes
NAME             STATUS   ROLES           AGE   VERSION
docker-desktop   Ready    control-plane   11d   v1.34.1
```

---

## 2. Imagen construida y publicada en Docker Hub

### 2.1 Compilación y construcción

```powershell
.\mvnw.cmd clean package -DskipTests
docker build -t sodasi/catalog-service:1.0.0 .
```

### 2.2 Publicación

```powershell
docker login
docker push sodasi/catalog-service:1.0.0
```

![docker push exitoso](evidencias/01-docker-push.png)

![Tag 1.0.0 en Docker Hub](evidencias/02-dockerhub-tag.png)

### 2.3 Verificación de descarga desde Docker Hub

Se eliminó la imagen local y se descargó de nuevo desde el registro:

```
PS> docker image rm sodasi/catalog-service:1.0.0
Untagged: sodasi/catalog-service:1.0.0
Deleted: sha256:e70ec5bdfd7626377d3ae4ffeff07ee27e9361ee29dc4f23a39f695407831d51

PS> docker pull sodasi/catalog-service:1.0.0
1.0.0: Pulling from sodasi/catalog-service
5b559c472d95: Pull complete
e4ffed9adc57: Pull complete
9318397b3db2: Pull complete
97b8bcda5c58: Pull complete
85afa86da4e6: Download complete
Digest: sha256:e70ec5bdfd7626377d3ae4ffeff07ee27e9361ee29dc4f23a39f695407831d51
Status: Downloaded newer image for sodasi/catalog-service:1.0.0
docker.io/sodasi/catalog-service:1.0.0
```

El `Digest` de la imagen descargada coincide con el de la imagen construida localmente, lo que confirma que es la misma.

---

## 3. Manifiestos YAML actualizados

### 3.1 `k8s/01-deployment.yaml`

Se cambió la imagen por la publicada en Docker Hub y el puerto del contenedor y de los probes a 8081:

```yaml
        image: sodasi/catalog-service:1.0.0
        ports:
        - containerPort: 8081
          name: http
        readinessProbe:
          httpGet:
            path: /ready
            port: 8081
        livenessProbe:
          httpGet:
            path: /live
            port: 8081
```

### 3.2 `k8s/02-service.yaml`

El laboratorio indica que este archivo no requiere cambios, pero se ajustó el `targetPort` porque la aplicación escucha en 8081:

```yaml
  ports:
  - port: 8080        # Puerto del Service dentro del clúster
    targetPort: 8081  # Puerto del contenedor
    protocol: TCP
    name: http
```

![Contenido de 01-deployment.yaml](evidencias/03-deployment-yaml.png)

---

## 4. Despliegue en Kubernetes y health checks automáticos

### 4.1 Primer despliegue: falla detectada por los health checks

El primer despliegue usó los YAML con el puerto 8080, pero la aplicación dentro del contenedor escuchaba en 8081. Los eventos muestran que Kubernetes descargó la imagen desde Docker Hub y luego detectó que la aplicación no respondía:

```
Events:
  Type     Reason     Age                  Message
  ----     ------     ----                 -------
  Normal   Scheduled  2m44s                Successfully assigned default/catalog-service-654649766d-b5gjz to docker-desktop
  Normal   Pulling    2m42s                Pulling image "sodasi/catalog-service:1.0.0"
  Normal   Pulled     110s                 Successfully pulled image "sodasi/catalog-service:1.0.0" in 52.468s (52.468s including waiting). Image size: 169711636 bytes.
  Warning  Unhealthy  23s (x7 over 93s)    Liveness probe failed: Get "http://10.1.0.14:8080/live": dial tcp 10.1.0.14:8080: connect: connection refused
  Warning  Unhealthy  15s (x18 over 102s)  Readiness probe failed: Get "http://10.1.0.14:8080/ready": dial tcp 10.1.0.14:8080: connect: connection refused
  Normal   Killing    3s (x3 over 73s)     Container catalog-service failed liveness probe, will be restarted
```

El log de la aplicación confirmó la causa:

```
INFO  [io.quarkus] (main) catalog-service 1.0.0 on JVM (powered by Quarkus 3.38.0) started in 2.907s. Listening on: http://0.0.0.0:8081
```

```
PS> Select-String -Path src\main\resources\application.properties -Pattern "port"
src\main\resources\application.properties:5:quarkus.http.port=8081
```

**Comportamiento observado:** la `readinessProbe` falló y Kubernetes mantuvo el pod fuera del tráfico (`READY 0/1`). La `livenessProbe` falló 3 veces seguidas y Kubernetes reinició el contenedor automáticamente, hasta acumular 6 reinicios.

![Eventos del primer despliegue](evidencias/04-primer-despliegue-eventos.png)

### 4.2 Corrección y despliegue exitoso

Después de ajustar los puertos en los YAML (sección 3) y volver a aplicarlos, Kubernetes reemplazó el pod fallido por uno nuevo:

```
PS> kubectl apply -f k8s\01-deployment.yaml
PS> kubectl apply -f k8s\02-service.yaml
service/catalog-service configured

PS> kubectl get pods -l app=catalog-service
NAME                               READY   STATUS        RESTARTS   AGE
catalog-service-654649766d-b5gjz   0/1     Terminating   6          6m50s
catalog-service-7d576bdf87-vcsnb   1/1     Running       0          10s
```

Estado del pod nuevo:

```
PS> kubectl describe pod -l app=catalog-service
Name:             catalog-service-7d576bdf87-vcsnb
Status:           Running
Containers:
  catalog-service:
    Image:          sodasi/catalog-service:1.0.0
    Port:           8081/TCP (http)
    State:          Running
    Ready:          True
    Restart Count:  0
    Liveness:       http-get http://:8081/live delay=10s timeout=2s period=10s #success=1 #failure=3
    Readiness:      http-get http://:8081/ready delay=5s timeout=2s period=5s #success=1 #failure=2
Conditions:
  Type                        Status
  Ready                       True
  ContainersReady             True
Events:
  Type     Reason     Age                Message
  ----     ------     ----               -------
  Normal   Scheduled  2m25s              Successfully assigned default/catalog-service-7d576bdf87-vcsnb to docker-desktop
  Normal   Pulled     2m24s              Container image "sodasi/catalog-service:1.0.0" already present on machine
  Normal   Created    2m23s              Created container: catalog-service
  Normal   Started    2m23s              Started container catalog-service
  Warning  Unhealthy  16s (x2 over 96s)  Readiness probe failed: HTTP probe failed with statuscode: 503
```

**Notas sobre los eventos:**

- `already present on machine`: la imagen ya se había descargado de Docker Hub para el primer pod (sección 4.1), así que no se volvió a descargar.
- Kubernetes no registra eventos cuando los probes tienen éxito, solo cuando fallan. La validación exitosa se demuestra con `Ready: True`, `Restart Count: 0` y `READY 1/1`.
- Las 2 fallas `503` de `/ready` en 96 segundos corresponden a la simulación de 95% de disponibilidad del endpoint. A diferencia del primer despliegue, la aplicación sí respondía; Kubernetes retiró el pod del tráfico momentáneamente y lo reincorporó **sin reiniciarlo**.

![Pod en estado Running 1/1](evidencias/05-pod-running.png)

---

## 5. Validación del funcionamiento del servicio

Acceso mediante `port-forward` (puerto 8081 local, porque el 8080 está ocupado por otro proceso en el equipo):

```
PS> kubectl port-forward svc/catalog-service 8081:8080
Forwarding from 127.0.0.1:8081 -> 8081
Forwarding from [::1]:8081 -> 8081
```

### 5.1 Endpoint principal

```
PS> curl.exe -i http://localhost:8081/v1/products
HTTP/1.1 200 OK
Content-Type: application/json;charset=UTF-8

{"status":"SUCCESS","data":["Product A","Product B","Product C"]}
```

![Respuesta DEGRADED_CACHE](evidencias/06-degraded-cache.png)

### 5.2 Health checks

```
PS> curl.exe -i http://localhost:8081/health
HTTP/1.1 200 OK
{
    "status": "UP",
    "checks": [
        {
            "name": "catalog-database-check",
            "status": "UP"
        }
    ]
}

PS> curl.exe -i http://localhost:8081/ready
HTTP/1.1 200 OK
{
    "status": "UP",
    "checks": [
        {
            "name": "catalog-database-check",
            "status": "UP"
        }
    ]
}

PS> curl.exe -i http://localhost:8081/live
HTTP/1.1 200 OK
{
    "status": "UP",
    "checks": [
    ]
}
```

---

## 6. Explicación técnica

Compilé el `catalog-service` con Maven y construí la imagen `sodasi/catalog-service:1.0.0` con Docker. La subí a Docker Hub con `docker push`, lo que la hace descargable desde cualquier equipo; lo verifiqué borrándola localmente y descargándola con `docker pull`. En `k8s/01-deployment.yaml` declaré la imagen de Docker Hub y los health checks: `readinessProbe` sobre `/ready` cada 5 s y `livenessProbe` sobre `/live` cada 10 s. Al aplicar el manifiesto, Kubernetes descargó la imagen (eventos `Pulling` y `Pulled`, 52 s) y comenzó a validar los probes automáticamente.

El primer despliegue falló: la aplicación escuchaba en el puerto 8081, configurado en `application.properties`, y los probes buscaban el 8080. Kubernetes detectó el `connection refused`, marcó el pod como no listo y lo reinició 6 veces. Ajusté `containerPort`, los probes y el `targetPort` del Service a 8081, y el nuevo pod quedó en `1/1 Running` sin reinicios. Las fallas ocasionales 503 en `/ready` corresponden a la simulación de 95% de disponibilidad: el pod sale temporalmente del Service sin reiniciarse.

En el Lab 1.1 validé estos endpoints manualmente con `curl`; en Kubernetes se validan de forma continua y automática, lo que permite retirar o reemplazar pods dañados sin intervención.

---

## 7. Limpieza

```powershell
kubectl delete deployment catalog-service
kubectl delete service catalog-service
```

---

## 8. Diferencias respecto al laboratorio original

| Aspecto | Laboratorio | Este despliegue | Motivo |
|---|---|---|---|
| Puerto de la aplicación | 8080 | 8081 | El puerto 8080 está ocupado por otro proceso en el equipo |
| `containerPort` y probes | 8080 | 8081 | Deben coincidir con el puerto real de la aplicación |
| `targetPort` del Service | 8080 | 8081 | El Service debe enviar el tráfico al puerto del contenedor |
| `port-forward` | `8080:8080` | `8081:8080` | El puerto local 8080 está ocupado |
| Comandos | Bash (`cat`, `grep`, `jq`) | PowerShell (`Get-Content`, `Select-String`, `curl.exe`) | Entorno Windows |
