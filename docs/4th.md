# Четвертый шаг: Service и доступ к приложению

На прошлом шаге мы создали `Deployment`, который поддерживает 3 реплики приложения.

Цепочка была такая:

```text
Deployment → ReplicaSet → Pod
```

Теперь добавляем `Service`.

`Service` нужен, чтобы дать стабильную точку доступа к группе Pod.

## Проблема

У каждого Pod есть свой IP внутри Kubernetes-кластера.

Например:

```text
hello-deployment-xxxxx-abcde   10.244.1.3
hello-deployment-xxxxx-fghij   10.244.2.4
hello-deployment-xxxxx-klmno   10.244.1.5
```

Но Pod — временная сущность.

Если Pod удалить, Deployment создаст новый Pod, но новый Pod может получить другой IP.

Например:

```text
было: 10.244.1.3
стало: 10.244.2.7
```

Поэтому обращаться напрямую к Pod IP неправильно.

Для стабильного доступа используют `Service`.

## Что такое Service

`Service` — это Kubernetes-объект, который дает стабильный адрес для доступа к группе Pod.

Он выбирает Pod по `labels`.

Упрощенно:

```text
Service
  ↓ selector app=hello
Pod app=hello
Pod app=hello
Pod app=hello
```

То есть `Service` говорит:

```text
Я буду отправлять трафик на все Pod, у которых есть label app=hello.
```

## Как выглядит схема

```text
Client inside cluster
  ↓
Service: hello-service
  ↓
Endpoints / EndpointSlice
  ↓
Pod 1: app=hello
Pod 2: app=hello
Pod 3: app=hello
```

Service сам контейнеры не запускает.

Он только дает стабильную сетевую точку доступа к Pod.

## Манифест Service

Файл:

```text
k8s/03-service/service.yaml
```

Содержимое:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: hello-service
  namespace: lab
  labels:
    app: hello
spec:
  type: ClusterIP
  selector:
    app: hello
  ports:
    - name: http
      protocol: TCP
      port: 80
      targetPort: 80
```

## Разбор манифеста

### `apiVersion`

```yaml
apiVersion: v1
```

Для `Service` используется базовая API-группа Kubernetes — `v1`.

### `kind`

```yaml
kind: Service
```

Тип объекта — `Service`.

Мы говорим Kubernetes:

```text
Создай объект Service.
```

### `metadata`

```yaml
metadata:
  name: hello-service
  namespace: lab
  labels:
    app: hello
```

`metadata` описывает сам Service:

* `name` — имя Service;
* `namespace` — namespace, где создать Service;
* `labels` — метки самого Service.

Важно: labels на Service — это просто метаданные Service.

Pod выбираются не через `metadata.labels`, а через `spec.selector`.

### `type`

```yaml
spec:
  type: ClusterIP
```

`ClusterIP` — тип Service по умолчанию.

Он создает внутренний IP внутри Kubernetes-кластера.

Такой Service доступен только внутри кластера.

Пример:

```text
hello-service.lab.svc.cluster.local
```

Снаружи кластера этот адрес недоступен.

Для внешнего доступа позже будем использовать:

* `NodePort`;
* `LoadBalancer`;
* `Ingress`.

### `selector`

```yaml
selector:
  app: hello
```

`selector` говорит Service, на какие Pod отправлять трафик.

В нашем случае Service ищет Pod с label:

```text
app=hello
```

Эти labels есть в Deployment:

```yaml
template:
  metadata:
    labels:
      app: hello
```

То есть связка такая:

```text
Service selector app=hello
  ↓
Pod labels app=hello
```

Если selector не совпадает с labels Pod, Service будет существовать, но не будет иметь backend Pod.

### `ports`

```yaml
ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 80
```

Разберем поля:

```text
name       — имя порта
protocol   — протокол, обычно TCP
port       — порт самого Service
targetPort — порт внутри Pod/контейнера
```

В нашем случае:

```text
Service слушает порт 80
  ↓
отправляет трафик на port 80 внутри Pod
```

То есть:

```text
hello-service:80 → Pod:80
```

## Makefile для четвертого шага

В `Makefile` можно добавить:

```makefile
# 4th lab

.PHONY: apply-service-4
apply-service-4:
	kubectl apply -f k8s/03-service/service.yaml

.PHONY: get-service-4
get-service-4:
	kubectl get svc -n lab

.PHONY: describe-service-4
describe-service-4:
	kubectl describe svc hello-service -n lab

.PHONY: get-endpoints-4
get-endpoints-4:
	kubectl get endpoints -n lab

.PHONY: get-endpointslice-4
get-endpointslice-4:
	kubectl get endpointslice -n lab

.PHONY: forward-service-4
forward-service-4:
	kubectl port-forward svc/hello-service 8080:80 -n lab

.PHONY: test-service-4
test-service-4:
	kubectl run curl-test --rm -it --image=curlimages/curl:8.10.1 -n lab -- curl http://hello-service

.PHONY: delete-service-4
delete-service-4:
	kubectl delete -f k8s/03-service/service.yaml
```

## 1. Перед началом должен быть запущен Deployment

Service будет выбирать Pod по label `app=hello`.

Поэтому сначала нужно, чтобы был создан Deployment из прошлого шага:

```bash
make apply-deploy-3
```

Проверить Pod:

```bash
make get-pods-3
```

Ожидаемо должно быть 3 Pod со статусом `Running`.

## 2. Создать Service

```bash
make apply-service-4
```

Ожидаемый результат:

```text
service/hello-service created
```

Если Service уже был создан:

```text
service/hello-service unchanged
```

или:

```text
service/hello-service configured
```

## 3. Проверить Service

```bash
make get-service-4
```

Ожидаемый результат:

```text
NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
hello-service   ClusterIP   10.96.xxx.xxx   <none>        80/TCP    10s
```

Что это значит:

```text
NAME        — имя Service
TYPE        — тип Service
CLUSTER-IP  — внутренний IP Service внутри кластера
EXTERNAL-IP — внешний IP, для ClusterIP его нет
PORT(S)     — порт Service
AGE         — сколько времени существует Service
```

Важно:

```text
CLUSTER-IP — стабильный внутренний IP Service.
```

Pod могут удаляться и создаваться заново, но Service остается стабильной точкой доступа.

## 4. Посмотреть подробное описание Service

```bash
make describe-service-4
```

Пример важной части вывода:

```text
Name:              hello-service
Namespace:         lab
Type:              ClusterIP
IP:                10.96.xxx.xxx
Port:              http  80/TCP
TargetPort:        80/TCP
Endpoints:         10.244.1.3:80,10.244.2.4:80,10.244.1.5:80
```

Особенно важно поле:

```text
Endpoints
```

Оно показывает, на какие Pod реально указывает Service.

Если `Endpoints` пустой, значит Service не нашел Pod по selector.

Частая причина:

```text
selector Service не совпадает с labels Pod.
```

## 5. Проверить Endpoints

```bash
make get-endpoints-4
```

Ожидаемо:

```text
NAME            ENDPOINTS                                      AGE
hello-service   10.244.1.3:80,10.244.2.4:80,10.244.1.5:80      1m
```

`Endpoints` — это список IP Pod, на которые Service отправляет трафик.

Если у нас 3 Pod, то обычно будет 3 endpoint.

## 6. Проверить EndpointSlice

```bash
make get-endpointslice-4
```

В современных Kubernetes вместо старого механизма `Endpoints` активно используется `EndpointSlice`.

Ожидаемо увидишь примерно:

```text
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS                         AGE
hello-service-xxxxx   IPv4          80      10.244.1.3,10.244.2.4,10.244.1.5   1m
```

Коротко:

```text
Endpoints     — старый объект со списком backend Pod
EndpointSlice — более современный и масштабируемый вариант
```

Для обучения полезно смотреть оба.

## 7. Проверить Service через port-forward

Service типа `ClusterIP` доступен только внутри кластера.

Но для проверки с локальной машины можно сделать port-forward:

```bash
make forward-service-4
```

Эта команда пробросит:

```text
localhost:8080 → hello-service:80 → Pod:80
```

В другом терминале:

```bash
curl http://localhost:8080
```

Ожидаемо вернется HTML-страница nginx:

```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
...
```

Теперь запрос идет не напрямую в Pod, а через Service.

## 8. Проверить Service изнутри кластера

Можно создать временный Pod с `curl` и выполнить запрос к Service:

```bash
make test-service-4
```

Фактически команда выполняет:

```bash
kubectl run curl-test --rm -it --image=curlimages/curl:8.10.1 -n lab -- curl http://hello-service
```

Что здесь происходит:

```text
kubectl run curl-test       — создать временный Pod
--rm                        — удалить Pod после завершения
-it                         — интерактивный режим
--image=curlimages/curl     — образ с curl
-n lab                      — namespace lab
-- curl http://hello-service — команда внутри Pod
```

Почему можно писать просто:

```text
http://hello-service
```

Потому что временный Pod и Service находятся в одном namespace `lab`.

Полное DNS-имя Service:

```text
hello-service.lab.svc.cluster.local
```

Из другого namespace нужно обращаться так:

```text
http://hello-service.lab.svc.cluster.local
```

## 9. Проверить, что Service переживает пересоздание Pod

Сначала посмотрим endpoints:

```bash
make get-endpoints-4
```

Потом удалим один Pod из Deployment:

```bash
kubectl delete pod <pod-name> -n lab
```

Проверим Pod:

```bash
make get-pods-3
```

Deployment создаст новый Pod.

Теперь снова проверим endpoints:

```bash
make get-endpoints-4
```

Ты увидишь, что список IP мог измениться.

Но Service остался тот же:

```text
hello-service
```

И доступ к приложению продолжает работать.

Это главная идея Service:

```text
Pod меняются.
Pod IP меняются.
Service остается стабильным.
```

## 10. Удалить Service

```bash
make delete-service-4
```

Проверить:

```bash
make get-service-4
```

После удаления Service исчезнет, но Deployment и Pod останутся.

То есть:

```text
Service удален
Pod продолжают работать
```

Service — это только сетевой доступ к Pod, а не сам запуск приложения.

## Важная связка selector и labels

Service находит Pod через selector:

```yaml
selector:
  app: hello
```

Pod имеют labels:

```yaml
template:
  metadata:
    labels:
      app: hello
```

Связка:

```text
Service selector app=hello
  ↓
Pod label app=hello
```

Если поменять Service selector на неправильный:

```yaml
selector:
  app: wrong
```

Service не найдет Pod.

Тогда:

```bash
make describe-service-4
```

покажет:

```text
Endpoints: <none>
```

Service будет создан, но трафик идти не будет.

## Типы Service

Основные типы Service:

```text
ClusterIP    — доступ только внутри кластера
NodePort     — открывает порт на каждой node
LoadBalancer — просит внешний балансировщик
ExternalName — DNS-алиас на внешний адрес
```

На этом шаге мы используем:

```text
ClusterIP
```

Потому что сейчас изучаем внутренний доступ внутри кластера.

Позже внешний доступ будем делать через:

```text
Ingress
```

## Чем Service отличается от Deployment

`Deployment` отвечает за запуск приложения:

```text
Deployment → ReplicaSet → Pod
```

`Service` отвечает за сетевой доступ к Pod:

```text
Service → Pod
```

То есть:

```text
Deployment создает Pod.
Service находит Pod и отправляет на них трафик.
```

## Что важно понять после четвертого шага

После этого шага нужно зафиксировать:

```text
Pod IP временный.

Service дает стабильную точку доступа к Pod.

Service выбирает Pod по labels через selector.

ClusterIP доступен только внутри Kubernetes-кластера.

Endpoints показывают реальные Pod IP, на которые смотрит Service.

EndpointSlice — современный механизм хранения backend endpoints.

Если selector не совпадает с labels Pod, Service не будет работать.

Service не запускает Pod, а только маршрутизирует трафик к ним.
```

## Мини-конспект

Было:

```text
Deployment → ReplicaSet → Pod
```

Стало:

```text
Client
  ↓
Service
  ↓
Pod 1
Pod 2
Pod 3
```

Полная схема:

```text
Client inside cluster
  ↓
hello-service:80
  ↓
Endpoints / EndpointSlice
  ↓
Pod IP:80
  ↓
nginx container
```

Команда:

```bash
make apply-service-4
```

фактически выполняет:

```bash
kubectl apply -f k8s/03-service/service.yaml
```

После этого Kubernetes создает объект `Service`, который следит за Pod с label:

```text
app=hello
```

Главная мысль:

```text
Deployment отвечает за количество Pod.
Service отвечает за стабильный доступ к этим Pod.
```

## Проверочный сценарий

Для закрепления выполни:

```bash
make apply-deploy-3
make get-pods-3
make apply-service-4
make get-service-4
make describe-service-4
make get-endpoints-4
make get-endpointslice-4
```

Проверить доступ через Service:

```bash
make forward-service-4
```

В другом терминале:

```bash
curl http://localhost:8080
```

Проверить доступ изнутри кластера:

```bash
make test-service-4
```

Проверить пересоздание Pod:

```bash
make get-endpoints-4
kubectl delete pod <pod-name> -n lab
make get-pods-3
make get-endpoints-4
```

В конце удалить Service:

```bash
make delete-service-4
```
