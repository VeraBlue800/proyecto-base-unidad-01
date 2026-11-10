# Explicación de la bitácora: `availability-baseline.txt`

**Laboratorio 1.1: Línea base de disponibilidad (sin patrones de resiliencia)**

## Contexto de la prueba

- **Servicio:** `catalog-service` (Quarkus) en modo dev.
- **Puerto:** 8081, porque el 8080 estaba ocupado por otro proceso en el equipo.
- **Endpoint probado:** `GET /v1/products`.
- **Carga:** 200 solicitudes secuenciales con `test-availability.ps1`.
- **Código:** versión original, sin anotaciones de tolerancia a fallos.

El endpoint simula tres comportamientos de forma aleatoria: respuesta exitosa inmediata (~50%), falla de conexión a la base de datos que termina en HTTP 500 (~30%) y latencia alta de 3000 ms que sí termina en HTTP 200 (~20%).

## Formato de la bitácora

Cada línea contiene: número de solicitud, código HTTP, tiempo total en segundos y cuerpo de la respuesta. Por ejemplo:

```
001 200 0.012 {"status":"SUCCESS","data":[...]}
```

## Resultados

| Métrica | Valor |
|---|---|
| Solicitudes totales | 200 |
| Respuestas HTTP 200 (`SUCCESS`) | 126 (63%) |
| Respuestas distintas de 200 | 74 (37%) |
| Disponibilidad observada | **0.63** |
| Latencia máxima | 3.028 s |
| Latencia promedio | 0.745 s |

## Comportamiento observado

**Las fallas llegan directo al cliente.** El 37% de las solicitudes terminó en error. Cuando la "base de datos" falla, el servicio no tiene ningún mecanismo para reintentar ni para dar una respuesta alternativa: la excepción se propaga y el cliente recibe un HTTP 500. Es un modelo de "éxito total o error total".

**La latencia alta bloquea al cliente.** Las solicitudes afectadas por la latencia simulada tardaron cerca de 3 segundos (máximo de 3.028 s). Durante ese tiempo el cliente queda esperando sin límite, porque el servicio no define un tiempo máximo de respuesta. Esas solicitudes elevan el promedio a 0.745 s, aunque la mayoría responde en milisegundos.

**La disponibilidad no refleja toda la degradación.** Las respuestas lentas cuentan como "disponibles" porque terminan en HTTP 200, pero para un usuario real una espera de 3 segundos también es una mala experiencia. Por eso la disponibilidad debe analizarse junto con la latencia.

**El resultado coincide con lo esperado.** La disponibilidad de 0.63 está dentro del rango de 0.60 a 0.75 que indica el laboratorio. La diferencia entre el 37% de errores observado y el 30% teórico se explica por la variación aleatoria de la simulación en una muestra de 200 solicitudes.

## Health checks

> Completar con los resultados obtenidos en el Paso 2:
>
> - `/health`:
> - `/ready`: (simula 95% de disponibilidad; puede responder `DOWN` ocasionalmente)
> - `/live`:

## Conclusión

Sin patrones de resiliencia, el servicio es frágil ante fallas de su dependencia: cerca de 4 de cada 10 solicitudes fallan y algunas bloquean al cliente durante 3 segundos. Esta bitácora es la línea base contra la que se comparan los cambios del Laboratorio 1.2.
