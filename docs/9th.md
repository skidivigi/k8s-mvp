# Девятый шаг: Probes, requests и limits

На этом шаге разбираем две важные production-темы:

```text
Probes    — проверки здоровья приложения.
Resources — запросы и лимиты CPU/RAM.
```

До этого мы запускали Pod, Deployment, Service, Ingress, PVC и StatefulSet.

Теперь нужно понять, как Kubernetes решает:

```text
Можно ли отправлять трафик в Pod?
Нужно ли перезапустить контейнер?
Хватает ли node ресурсов для запуска Pod?
Сколько CPU/RAM приложению разрешено использовать?
```

## Зачем нужны probes

Kubernetes сам по себе не знает, работает ли приложение корректно.

Для Kubernetes состояние контейнера `Running` означает только:

```text
процесс внутри контейнера запущен
```

Но это не значит, что приложение реально готово принимать запросы.

Например:

```text
контейнер запущен, но приложение еще грузит конфиг;
приложение запущено, но не может подключиться к базе;
процесс живой, но HTTP-сервер завис;
приложение стартует долго и его нельзя сразу убивать.
```

Для этого используют probes.

## Виды probes

В Kubernetes есть три основные проверки:

```text
startupProbe   — приложение уже стартовало?
readinessProbe — приложение готово принимать трафик?
livenessProbe  — приложение живое или его надо перезапустить?
```

## startupProbe

`startupProbe` нужна для приложений, которые могут долго стартовать.

Пока `startupProbe` не прошла успешно, Kubernetes не запускает `livenessProbe` и `readinessProbe`.

Это защищает медленно стартующее приложение от преждевременного рестарта.

Пример:

```yaml
startupProbe:
  httpGet:
    path: /
    port: 80
  failureThreshold: 30
  periodSeconds: 2
```

Что это значит:

```text
Проверять / каждые 2 секунды.
Разрешить до 30 неудачных попыток.
Максимальное время на старт примерно 60 секунд.
```

Формула:

```text
failureThreshold × periodSeconds = максимальное время ожидания
```

В нашем случае:

```text
30 × 2 = 60 секунд
```

Если приложение за это время не стартовало, контейнер будет перезапущен.

## readinessProbe

`readinessProbe` отвечает на вопрос:

```text
Готов ли Pod принимать трафик?
```

Если `readinessProbe` не проходит, Pod остается Running, но Service не будет отправлять на него трафик.

Это очень важно.

Схема:

```text
readinessProbe OK
  ↓
Pod попадает в Endpoints Service
  ↓
Service может отправлять трафик в Pod
```

Если readiness не проходит:

```text
readinessProbe FAIL
  ↓
Pod убирается из Endpoints Service
  ↓
Service не отправляет трафик в этот Pod
```

Пример:

```yaml
readinessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 3
  periodSeconds: 5
  timeoutSeconds: 2
  failureThreshold: 3
```

Разбор:

```text
initialDelaySeconds: 3 — подождать 3 секунды после старта контейнера
periodSeconds: 5      — проверять каждые 5 секунд
timeoutSeconds: 2     — ждать ответ не дольше 2 секунд
failureThreshold: 3   — после 3 ошибок считать Pod not ready
```

## livenessProbe

`livenessProbe` отвечает на вопрос:

```text
Живо ли приложение?
```

Если `livenessProbe` не проходит, Kubernetes перезапускает контейнер.

Пример:

```yaml
livenessProbe:
  httpGet:
    path: /
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 2
  failureThreshold: 3
```

Схема:

```text
livenessProbe OK
  ↓
контейнер продолжает работать
```

Если liveness падает:

```text
livenessProbe FAIL
  ↓
Kubernetes перезапускает контейнер
```

Важно:

```text
readinessProbe убирает Pod из трафика.
livenessProbe перезапускает контейнер.
```

Это разные вещи.

## Главное отличие readiness и liveness

`readinessProbe` не перезапускает контейнер.

Она только говорит Service:

```text
Пока не отправляй сюда трафик.
```

`livenessProbe` не занимается балансировкой трафика.

Она говорит kubelet:

```text
Контейнер сломан, перезапусти его.
```

Коротко:

```text
readiness = можно ли давать трафик
liveness  = надо ли рестартить
startup   = дай приложению спокойно стартовать
```

## Какие бывают типы probes

Probes можно делать разными способами.

### HTTP GET

Самый частый вариант для web-приложений:

```yaml
httpGet:
  path: /health
  port: 8080
```

Kubernetes делает HTTP-запрос внутрь контейнера.

Успешные коды:

```text
200-399
```

### TCP socket

Проверяет, открыт ли TCP-порт:

```yaml
tcpSocket:
  port: 5432
```

Полезно, если приложение не имеет HTTP endpoint.

### exec

Выполняет команду внутри контейнера:

```yaml
exec:
  command:
    - cat
    - /tmp/healthy
```

Если команда возвращает exit code `0`, проверка успешна.

Если не `0`, проверка провалена.

## Почему не всегда надо ставить livenessProbe

`livenessProbe` может навредить, если настроена неправильно.

Например, приложение временно тормозит из-за высокой нагрузки, а probe слишком агрессивная.

Тогда Kubernetes начнет его рестартить, и станет еще хуже.

Плохая ситуация:

```text
приложение под нагрузкой отвечает медленно
  ↓
livenessProbe fail
  ↓
restart
  ↓
приложение снова долго стартует
  ↓
еще больше ошибок
```

Поэтому часто начинают с:

```text
readinessProbe
resources.requests/limits
```

А `livenessProbe` добавляют аккуратно.

## Зачем нужны resources

Kubernetes планирует Pod на node через scheduler.

Scheduler должен понимать:

```text
Сколько CPU нужно Pod?
Сколько RAM нужно Pod?
На какой node есть место?
```

Для этого используются `resources.requests`.

А чтобы контейнер не мог съесть слишком много, используются `resources.limits`.

## requests

`requests` — это минимально запрошенные ресурсы.

Пример:

```yaml
resources:
  requests:
    cpu: "100m"
    memory: "64Mi"
```

Это значит:

```text
Для планирования Pod нужно зарезервировать:
CPU: 100m
RAM: 64Mi
```

`100m` CPU означает:

```text
100 millicpu = 0.1 CPU core
```

Примеры:

```text
100m  = 0.1 CPU
500m  = 0.5 CPU
1000m = 1 CPU
2000m = 2 CPU
```

Memory:

```text
64Mi  = 64 mebibytes
128Mi = 128 mebibytes
1Gi   = 1 gibibyte
```

Scheduler использует requests.

То есть если node не имеет свободных ресурсов под requests, Pod останется в `Pending`.

## limits

`limits` — это верхняя граница ресурсов.

Пример:

```yaml
resources:
  limits:
    cpu: "500m"
    memory: "128Mi"
```

Это значит:

```text
Контейнеру разрешено использовать максимум:
CPU: 500m
RAM: 128Mi
```

Но CPU и memory ведут себя по-разному.

## CPU limit

Если контейнер превышает CPU limit, Kubernetes обычно не убивает контейнер.

CPU будет ограничен, то есть throttled.

Схема:

```text
контейнер хочет больше CPU
  ↓
CPU throttling
  ↓
приложение работает медленнее
```

## Memory limit

Если контейнер превышает memory limit, контейнер может быть убит.

Обычно причина будет:

```text
OOMKilled
```

Схема:

```text
контейнер использует больше RAM, чем limit
  ↓
OOMKilled
  ↓
контейнер рестартится
```

Это важное отличие:

```text
CPU limit → замедление
Memory limit → убийство контейнера
```

## QoS Class

Kubernetes назначает Pod класс качества обслуживания — QoS.

Основные классы:

```text
BestEffort
Burstable
Guaranteed
```

### BestEffort

Если нет ни requests, ни limits:

```yaml
resources: {}
```

Pod получает QoS:

```text
BestEffort
```

Такие Pod первыми кандидаты на выселение при нехватке ресурсов на node.

### Burstable

Если requests и limits заданы, но они не равны:

```yaml
requests:
  cpu: "100m"
  memory: "64Mi"
limits:
  cpu: "500m"
  memory: "128Mi"
```

Pod получает QoS:

```text
Burstable
```

Это наш пример.

### Guaranteed

Если requests и limits одинаковые для CPU и memory:

```yaml
requests:
  cpu: "500m"
  memory: "128Mi"
limits:
  cpu: "500m"
  memory: "128Mi"
```

Pod получает QoS:

```text
Guaranteed
```

Такие Pod имеют самый высокий приоритет по ресурсной стабильности.

## Наш Deployment

Файл:

```text
k8s/08-probes-resources/deployment.yaml
```

Содержимое:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-probes
  namespace: lab
  labels:
    app: hello-probes
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-probes
  template:
    metadata:
      labels:
        app: hello-probes
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80

          resources:
            requests:
              cpu: "100m"
              memory: "64Mi"
            limits:
              cpu: "500m"
              memory: "128Mi"

          startupProbe:
            httpGet:
              path: /
              port: 80
            failureThreshold: 30
            periodSeconds: 2

          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
            periodSeconds: 5
            timeoutSeconds: 2
            failureThreshold: 3

          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10
            periodSeconds: 10
            timeoutSeconds: 2
            failureThreshold: 3
```

## Service

Файл:

```text
k8s/08-probes-resources/service.yaml
```

Содержимое:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-probes-service
  namespace: lab
  labels:
    app: hello-probes
spec:
  type: ClusterIP
  selector:
    app: hello-probes
  ports:
    - name: http
      port: 80
      targetPort: 80
```

Service нужен, чтобы увидеть влияние `readinessProbe`.

Если Pod не ready, он не должен попадать в Endpoints Service.

## Makefile для девятого шага

```makefile
# 9th lab - Probes and Resources

.PHONY: apply-probes-9
apply-probes-9:
	kubectl apply -f k8s/08-probes-resources/deployment.yaml
	kubectl apply -f k8s/08-probes-resources/service.yaml

.PHONY: get-probes-deploy-9
get-probes-deploy-9:
	kubectl get deploy hello-probes -n lab

.PHONY: get-probes-pods-9
get-probes-pods-9:
	kubectl get pods -n lab -l app=hello-probes -o wide

.PHONY: describe-probes-deploy-9
describe-probes-deploy-9:
	kubectl describe deploy hello-probes -n lab

.PHONY: describe-probes-pod-9
describe-probes-pod-9:
	kubectl describe pod -n lab -l app=hello-probes

.PHONY: get-probes-service-9
get-probes-service-9:
	kubectl get svc hello-probes-service -n lab

.PHONY: describe-probes-service-9
describe-probes-service-9:
	kubectl describe svc hello-probes-service -n lab

.PHONY: get-probes-endpoints-9
get-probes-endpoints-9:
	kubectl get endpoints hello-probes-service -n lab

.PHONY: forward-probes-9
forward-probes-9:
	kubectl port-forward svc/hello-probes-service 8083:80 -n lab

.PHONY: test-probes-9
test-probes-9:
	kubectl run curl-probes-test --rm -it --image=curlimages/curl:8.10.1 -n lab -- curl http://hello-probes-service

.PHONY: top-pods-9
top-pods-9:
	kubectl top pods -n lab

.PHONY: top-nodes-9
top-nodes-9:
	kubectl top nodes

.PHONY: delete-probes-9
delete-probes-9:
	kubectl delete -f k8s/08-probes-resources/service.yaml
	kubectl delete -f k8s/08-probes-resources/deployment.yaml
```

## 1. Применить манифесты

```bash
make apply-probes-9
```

Ожидаемо:

```text
deployment.apps/hello-probes created
service/hello-probes-service created
```

## 2. Проверить Deployment

```bash
make get-probes-deploy-9
```

Ожидаемо:

```text
NAME           READY   UP-TO-DATE   AVAILABLE
hello-probes   2/2     2            2
```

## 3. Проверить Pod

```bash
make get-probes-pods-9
```

Ожидаемо:

```text
NAME                            READY   STATUS    RESTARTS   AGE
hello-probes-xxxxxxxxx-xxxxx    1/1     Running   0          1m
hello-probes-xxxxxxxxx-yyyyy    1/1     Running   0          1m
```

Поле `READY` связано с readiness.

Если readiness не проходит, будет:

```text
READY 0/1
```

## 4. Посмотреть probes в describe

```bash
make describe-probes-pod-9
```

В выводе ищи:

```text
Liveness:
Readiness:
Startup:
```

Там будет видно, какие проверки настроены.

Также смотри `Events`.

Если probe падает, в событиях будут сообщения вроде:

```text
Readiness probe failed
Liveness probe failed
Startup probe failed
```

## 5. Проверить Endpoints

```bash
make get-probes-endpoints-9
```

Если Pod ready, Service будет иметь endpoints:

```text
NAME                   ENDPOINTS
hello-probes-service   10.244.1.10:80,10.244.2.11:80
```

Если readiness не проходит, Pod не будет попадать в endpoints.

Именно так Service понимает, куда можно отправлять трафик.

## 6. Проверить запросом изнутри кластера

```bash
make test-probes-9
```

Ожидаемо nginx вернет HTML-страницу.

## 7. Проверить через port-forward

```bash
make forward-probes-9
```

В другом терминале:

```bash
curl http://localhost:8083
```

## 8. Посмотреть requests и limits

```bash
kubectl describe pod -n lab -l app=hello-probes
```

Ищи блок:

```text
Requests:
  cpu:     100m
  memory:  64Mi
Limits:
  cpu:     500m
  memory:  128Mi
```

## 9. Посмотреть QoS Class

В том же `describe pod` ищи:

```text
QoS Class: Burstable
```

Почему `Burstable`?

Потому что requests и limits заданы, но они не равны:

```text
requests.cpu    100m
limits.cpu      500m

requests.memory 64Mi
limits.memory   128Mi
```

## 10. Если работает Metrics Server

Можно посмотреть потребление ресурсов:

```bash
make top-pods-9
```

Или:

```bash
make top-nodes-9
```

Если Metrics Server не установлен, будет ошибка.

Это нормально.

Пример ошибки:

```text
Metrics API not available
```

Позже в observability-теме можно будет отдельно поставить Metrics Server, Prometheus и Grafana.

## Полезная production-практика

Для web-приложений часто делают отдельные endpoints:

```text
/startupz
/readyz
/healthz
```

И настраивают так:

```yaml
startupProbe:
  httpGet:
    path: /startupz
    port: 8080

readinessProbe:
  httpGet:
    path: /readyz
    port: 8080

livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
```

Почему разные endpoints?

Потому что они отвечают на разные вопросы.

### `/readyz`

Проверяет:

```text
готово ли приложение принимать трафик
```

Например:

```text
подключение к базе есть
миграции выполнены
кэш прогрет
зависимости доступны
```

### `/healthz`

Проверяет:

```text
не зависло ли приложение полностью
```

Но сюда не всегда стоит включать внешние зависимости.

Например, если база временно недоступна, не всегда нужно рестартить приложение.

Часто правильнее:

```text
readiness падает → убрать Pod из трафика
liveness не падает → не рестартить приложение без причины
```

## Частая ошибка

Плохая практика:

```text
один и тот же endpoint /health для readiness и liveness
```

Почему плохо?

Если `/health` проверяет базу данных, то при временной проблеме с базой:

```text
readiness упадет — это нормально
liveness тоже упадет — Kubernetes начнет рестартить Pod
```

Но рестарт приложения не починит базу.

В итоге можно получить restart storm.

Лучше:

```text
readiness проверяет готовность обслуживать запросы
liveness проверяет, что процесс не завис
```

## Короткий пример для FastAPI

В приложении можно сделать так:

```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/healthz")
def healthz():
    return {"status": "alive"}

@app.get("/readyz")
def readyz():
    # тут можно проверить подключение к БД, Redis и т.п.
    return {"status": "ready"}
```

И в Kubernetes:

```yaml
readinessProbe:
  httpGet:
    path: /readyz
    port: 8000

livenessProbe:
  httpGet:
    path: /healthz
    port: 8000
```

## Что важно понять после девятого шага

После этого шага нужно зафиксировать:

```text
startupProbe нужна для долгого старта приложения.

readinessProbe решает, можно ли отправлять трафик в Pod.

livenessProbe решает, нужно ли перезапустить контейнер.

Service отправляет трафик только в ready endpoints.

requests используются scheduler для выбора node.

limits ограничивают максимальное потребление ресурсов.

CPU limit приводит к throttling.

Memory limit может привести к OOMKilled.

QoS Class зависит от requests и limits.

Для production важно задавать requests почти всегда.

Liveness нужно настраивать осторожно.
```

## Мини-конспект

```text
startupProbe
  ↓
"Приложение уже стартовало?"

readinessProbe
  ↓
"Можно ли давать трафик?"

livenessProbe
  ↓
"Нужно ли рестартить контейнер?"
```

```text
resources.requests
  ↓
"Сколько ресурсов зарезервировать при планировании?"

resources.limits
  ↓
"Сколько максимум можно использовать?"
```

Главная мысль:

```text
Probes управляют жизненным циклом и трафиком.

Resources управляют планированием и ограничением CPU/RAM.
```

## Проверочный сценарий

```bash
make apply-probes-9
make get-probes-deploy-9
make get-probes-pods-9
make describe-probes-pod-9
make get-probes-endpoints-9
make test-probes-9
```

Проверить Service через port-forward:

```bash
make forward-probes-9
```

В другом терминале:

```bash
curl http://localhost:8083
```

Проверить resources и QoS:

```bash
kubectl describe pod -n lab -l app=hello-probes
```

Ищи:

```text
Requests
Limits
QoS Class
Startup
Readiness
Liveness
```
