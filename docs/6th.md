# Шестой шаг: Ingress

На прошлом шаге мы создали `Service`, который дает стабильный доступ к Pod внутри Kubernetes-кластера.

Схема была такая:

```text
Client inside cluster
  ↓
Service
  ↓
Pod
```

Теперь добавляем `Ingress`.

`Ingress` нужен, чтобы описать HTTP/HTTPS-маршрутизацию снаружи кластера к сервисам внутри кластера.

## Что такое Ingress

`Ingress` — это Kubernetes-объект, который описывает правила входящего HTTP/HTTPS-трафика.

Например:

```text
hello.localhost/
  ↓
hello-service:80
```

Сам `Ingress` не принимает трафик.

Для работы нужен `Ingress Controller`.

## Что такое Ingress Controller

`Ingress Controller` — это реальный компонент, который принимает HTTP/HTTPS-трафик и применяет правила из объектов `Ingress`.

Упрощенно:

```text
Browser / curl
  ↓
Ingress Controller
  ↓
Ingress
  ↓
Service
  ↓
Pod
```

Примеры Ingress Controller:

```text
NGINX
Traefik
HAProxy
Envoy
F5 NGINX Ingress Controller
Cilium Gateway API
```

Важно:

```text
Ingress — это правило.
Ingress Controller — это тот, кто исполняет правило.
```

## Наша схема

После этого шага схема будет такой:

```text
curl http://hello.localhost
  ↓
localhost:80
  ↓
kind port mapping
  ↓
Ingress Controller
  ↓
Ingress hello-ingress
  ↓
Service hello-service
  ↓
Pod nginx
```

## Перед началом

У нас уже должны быть созданы:

```text
Deployment из 3-го шага
Service из 4-го шага
```

Проверить:

```bash
make get-pods-3
make get-service-4
make get-endpoints-4
```

Если Deployment или Service удалены, создать заново:

```bash
make apply-deploy-3
make apply-service-4
```

## Установка Ingress Controller

Для работы Ingress нужен контроллер.

В учебной kind-лаборатории можно установить NGINX Ingress Controller:

```bash
make install-ingress-controller-6
```

Сделать патч контроллера командой:
Более детально описано в [подробном описании](#важный-нюанс-kind-и-ingress-controller)

```bash
make fix-ingress-node-6
```

Подождать готовности controller Pod:

```bash
make wait-ingress-controller-6
```

Проверить:

```bash
make get-ingress-controller-6
```

Ожидаемо Pod контроллера должен быть в статусе `Running`.

Пример:

```text
NAME                                        READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxxxxxxxx-xxxxx    1/1     Running   0          1m
```

## Манифест Ingress

Файл:

```text
k8s/05-ingress/ingress.yaml
```

Содержимое:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-ingress
  namespace: lab
  labels:
    app: hello
spec:
  ingressClassName: nginx
  rules:
    - host: hello.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-service
                port:
                  number: 80
```

## Разбор манифеста

### `apiVersion`

```yaml
apiVersion: networking.k8s.io/v1
```

`Ingress` относится к API-группе `networking.k8s.io/v1`.

### `kind`

```yaml
kind: Ingress
```

Тип объекта — `Ingress`.

Мы говорим Kubernetes:

```text
Создай правило входящей HTTP-маршрутизации.
```

### `metadata`

```yaml
metadata:
  name: hello-ingress
  namespace: lab
  labels:
    app: hello
```

`metadata` описывает сам объект Ingress:

```text
name      — имя Ingress
namespace — namespace, где он создан
labels    — метки объекта
```

Важно: Ingress обычно должен находиться в том же namespace, что и backend Service.

В нашем случае:

```text
Ingress: lab/hello-ingress
Service: lab/hello-service
```

### `ingressClassName`

```yaml
ingressClassName: nginx
```

Это указание, какой Ingress Controller должен обработать этот Ingress.

Если в кластере несколько контроллеров, например NGINX и Traefik, то `ingressClassName` помогает выбрать нужный.

В нашем случае:

```text
ingressClassName: nginx
```

означает:

```text
Этот Ingress должен обработать nginx ingress controller.
```

### `rules`

```yaml
rules:
  - host: hello.localhost
```

`host` — HTTP hostname, для которого действует правило.

То есть правило сработает для запроса:

```text
http://hello.localhost
```

или для запроса на `localhost` с заголовком:

```text
Host: hello.localhost
```

### `paths`

```yaml
paths:
  - path: /
    pathType: Prefix
```

Это правило маршрутизации по HTTP path.

```text
path: /
```

означает, что правило подходит для всех путей, начинающихся с `/`.

Например:

```text
/
 /test
 /api
 /anything
```

`pathType: Prefix` означает маршрутизацию по префиксу пути.

### `backend`

```yaml
backend:
  service:
    name: hello-service
    port:
      number: 80
```

`backend` указывает, куда отправлять трафик.

В нашем случае:

```text
hello.localhost/
  ↓
Service hello-service:80
```

Дальше Service уже сам отправит трафик на один из Pod с label `app=hello`.

## Makefile для шестого шага

```makefile
# 6th lab

.PHONY: install-ingress-controller-6
install-ingress-controller-6:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

.PHONY: wait-ingress-controller-6
wait-ingress-controller-6:
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=180s

.PHONY: get-ingress-controller-6
get-ingress-controller-6:
	kubectl get pods -n ingress-nginx

.PHONY: apply-ingress-6
apply-ingress-6:
	kubectl apply -f k8s/05-ingress/ingress.yaml

.PHONY: get-ingress-6
get-ingress-6:
	kubectl get ingress -n lab

.PHONY: describe-ingress-6
describe-ingress-6:
	kubectl describe ingress hello-ingress -n lab

.PHONY: test-ingress-6
test-ingress-6:
	curl -H "Host: hello.localhost" http://localhost

.PHONY: test-ingress-host-6
test-ingress-host-6:
	curl http://hello.localhost

.PHONY: delete-ingress-6
delete-ingress-6:
	kubectl delete -f k8s/05-ingress/ingress.yaml
```

## 1. Установить Ingress Controller

```bash
make install-ingress-controller-6
```

Сделать патч контроллера командой:
Более детально описано в [подробном описании](#важный-нюанс-kind-и-ingress-controller)

```bash
make fix-ingress-node-6
```

Затем дождаться готовности:

```bash
make wait-ingress-controller-6
```

Проверить:

```bash
make get-ingress-controller-6
```

## 2. Применить Ingress

```bash
make apply-ingress-6
```

Ожидаемый результат:

```text
ingress.networking.k8s.io/hello-ingress created
```

Если объект уже был создан ранее:

```text
ingress.networking.k8s.io/hello-ingress unchanged
```

или:

```text
ingress.networking.k8s.io/hello-ingress configured
```

## 3. Проверить Ingress

```bash
make get-ingress-6
```

Пример вывода:

```text
NAME            CLASS   HOSTS             ADDRESS     PORTS   AGE
hello-ingress   nginx   hello.localhost    localhost   80      1m
```

Что важно:

```text
NAME   — имя Ingress
CLASS  — ingressClassName
HOSTS  — hostname, для которого действует правило
ADDRESS — адрес Ingress Controller
PORTS  — порты
AGE    — сколько времени существует объект
```

## 4. Посмотреть подробное описание Ingress

```bash
make describe-ingress-6
```

Важные поля:

```text
Rules
Backend
Events
```

Если Ingress Controller обработал правило, в events обычно будет видно, что конфигурация была принята.

## 5. Проверить доступ через Ingress

Вариант 1 — через Host header:

```bash
make test-ingress-6
```

Фактически выполняется:

```bash
curl -H "Host: hello.localhost" http://localhost
```

Ожидаемый ответ от nginx:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

Вариант 2 — напрямую через hostname:

```bash
make test-ingress-host-6
```

Фактически:

```bash
curl http://hello.localhost
```

Если `hello.localhost` не резолвится, можно использовать вариант с Host header или добавить запись в `/etc/hosts`.

Пример:

```text
127.0.0.1 hello.localhost
```

## Почему теперь не нужен port-forward

Раньше для доступа к Pod или Service мы делали:

```bash
kubectl port-forward ...
```

Это временный туннель для отладки.

Теперь трафик идет через нормальную Kubernetes-схему:

```text
localhost:80
  ↓
Ingress Controller
  ↓
Ingress rule
  ↓
Service
  ↓
Pod
```

`port-forward` не нужен для пользовательского HTTP-доступа.

## Чем Ingress отличается от Service

`Service` дает стабильный доступ к Pod внутри кластера.

```text
Service → Pod
```

`Ingress` описывает HTTP/HTTPS-вход снаружи кластера к Service.

```text
Ingress → Service → Pod
```

Коротко:

```text
Deployment — запускает Pod
Service    — дает стабильный внутренний адрес к Pod
Ingress    — дает HTTP-вход снаружи к Service
```

## Важная связка

В Ingress указано:

```yaml
backend:
  service:
    name: hello-service
    port:
      number: 80
```

Это значит:

```text
Ingress отправляет трафик в Service hello-service на порт 80.
```

А Service уже выбирает Pod через selector:

```yaml
selector:
  app: hello
```

То есть полная цепочка:

```text
Ingress host hello.localhost
  ↓
Service hello-service
  ↓
Pod with label app=hello
```

## Типичные ошибки

### 1. Нет Ingress Controller

Ingress создан, но трафик не идет.

Проверить:

```bash
make get-ingress-controller-6
```

Если controller Pod не запущен, Ingress никто не обрабатывает.

### 2. Service не найден

В Ingress указан неправильный Service:

```yaml
name: wrong-service
```

Проверить:

```bash
make describe-ingress-6
```

### 3. У Service нет Endpoints

Service есть, но он не нашел Pod.

Проверить:

```bash
make get-endpoints-4
```

Если:

```text
Endpoints: <none>
```

значит selector Service не совпадает с labels Pod.

### 4. Не совпадает Host

Ingress настроен на:

```text
hello.localhost
```

А запрос идет без такого Host header.

Проверить можно так:

```bash
curl -H "Host: hello.localhost" http://localhost
```

### 5. Не проброшены 80/443 в kind

В `kind/cluster.yaml` должны быть port mappings:

```yaml
extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

Без этого локальный `localhost:80` может не попасть в kind-кластер.

## Удалить Ingress

```bash
make delete-ingress-6
```

После удаления Ingress:

```text
Ingress исчезнет
Service останется
Pod останутся
Deployment останется
```

То есть мы удаляем только внешний HTTP-маршрут.

## Что важно понять после шестого шага

После этого шага нужно зафиксировать:

```text
Ingress описывает HTTP/HTTPS-маршруты.

Ingress сам не принимает трафик.

Для работы нужен Ingress Controller.

Ingress отправляет трафик в Service.

Service отправляет трафик на Pod.

Ingress работает на уровне HTTP host/path.

Service работает на уровне TCP/UDP.

port-forward нужен для отладки, Ingress — для нормального входа в приложение.
```

## Мини-конспект

Было:

```text
Service
  ↓
Pod
```

Стало:

```text
Browser / curl
  ↓
Ingress Controller
  ↓
Ingress
  ↓
Service
  ↓
Pod
```

Главная мысль:

```text
Service дает внутреннюю стабильную точку доступа.
Ingress дает HTTP-вход снаружи кластера.
```

## Проверочный сценарий

```bash
make apply-deploy-3
make apply-service-4

make install-ingress-controller-6
make wait-ingress-controller-6
make get-ingress-controller-6

make apply-ingress-6
make get-ingress-6
make describe-ingress-6
make test-ingress-6
```

Ожидаемо запрос должен вернуть HTML-страницу nginx.

## Важный нюанс kind и Ingress Controller

В kind-кластере мы пробрасываем локальные порты `80` и `443` в container `control-plane`.

Фрагмент `kind/cluster.yaml`:

```yaml
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 80
        hostPort: 80
        protocol: TCP
      - containerPort: 443
        hostPort: 443
        protocol: TCP
```

Это значит:

```text
localhost:80  → platform-lab-control-plane:80
localhost:443 → platform-lab-control-plane:443
```

Поэтому `ingress-nginx-controller` должен быть запущен именно на node:

```text
platform-lab-control-plane
```

Если controller запустится на worker-node, то `curl http://localhost` не попадет в Ingress Controller.

Проверить можно так:

```bash
kubectl get pods -n ingress-nginx -o wide
```

Ожидаемо:

```text
ingress-nginx-controller-xxxxx   1/1   Running   ...   platform-lab-control-plane
```

Для автоматической настройки используется команда:

```bash
make setup-ingress-6
```

Она делает несколько действий:

```text
1. Устанавливает ingress-nginx-controller.
2. Добавляет label ingress-ready=true на control-plane node.
3. Патчит Deployment ingress-nginx-controller.
4. Добавляет nodeSelector ingress-ready=true.
5. Перезапускает ingress-controller.
6. Ждет готовности controller Pod.
```

Главный patch:

```bash
kubectl patch deployment ingress-nginx-controller -n ingress-nginx \
  --type='merge' \
  -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux","ingress-ready":"true"}}}}}'
```

После этого scheduler будет запускать `ingress-nginx-controller` только на node с label:

```text
ingress-ready=true
```

То есть на:

```text
platform-lab-control-plane
```
