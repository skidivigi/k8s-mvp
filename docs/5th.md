# Пятый шаг: ConfigMap и Secret

На этом шаге разбираем, как передавать конфигурацию и чувствительные данные в Pod.

В прошлых шагах мы запускали `nginx` почти без настроек. Но в реальных приложениях нужно передавать:

- имя приложения;
- окружение;
- уровень логирования;
- адреса сервисов;
- логины;
- пароли;
- токены;
- конфигурационные файлы.

Для этого в Kubernetes используют:

```text
ConfigMap — обычная конфигурация
Secret    — чувствительные данные
```

## Что такое ConfigMap

*ConfigMap* — Kubernetes-объект для хранения обычной конфигурации.

Примеры данных для ConfigMap:

```text
APP_ENV=dev
LOG_LEVEL=debug
APP_NAME=hello-api
nginx.conf
application.yaml
```

ConfigMap не предназначен для паролей и токенов.

## Что такое Secret

*Secret* — Kubernetes-объект для хранения чувствительных данных.

Примеры:

```text
DB_USER
DB_PASSWORD
API_TOKEN
TLS certificate
Docker registry credentials
```

*Важно:* стандартный Kubernetes *Secret* — это не полноценный Vault.

По умолчанию значения Secret хранятся в base64, а *base64 — это не шифрование.*

В production для секретов часто используют:

```text
Vault
External Secrets Operator
Sealed Secrets
SOPS
cloud secret managers
```

## Главная разница

```text
ConfigMap — обычная конфигурация
Secret    — чувствительные данные
```

Пример:

```text
LOG_LEVEL=debug        → ConfigMap
DB_PASSWORD=password   → Secret
```

## ConfigMap

Файл:

```text
k8s/04-configmap-secret/configmap.yaml
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hello-config
  namespace: lab
data:
  APP_NAME: "hello-api"
  APP_ENV: "dev"
  LOG_LEVEL: "debug"
  nginx.conf: |
    server {
        listen 80;
        server_name localhost;

        location / {
            return 200 "Hello from ConfigMap nginx config\n";
        }
    }
```

## Разбор ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
```

Создаем объект типа ConfigMap.

```yaml
metadata:
  name: hello-config
  namespace: lab
```

ConfigMap будет создан в namespace lab.

```yaml
data:
  APP_NAME: "hello-api"
  APP_ENV: "dev"
  LOG_LEVEL: "debug"
```

Это обычные key-value параметры.

Их можно передать в контейнер как переменные окружения.

```yaml
nginx.conf: |
  server {
      listen 80;
      server_name localhost;

      location / {
          return 200 "Hello from ConfigMap nginx config\n";
      }
  }
```

Это пример хранения целого конфигурационного файла внутри ConfigMap.

Мы потом примонтируем его внутрь контейнера как файл.

## Secret

Файл:

```text
k8s/04-configmap-secret/secret.yaml
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hello-secret
  namespace: lab
type: Opaque
stringData:
  DB_USER: "demo_user"
  DB_PASSWORD: "demo_password"
```

## Разбор Secret

```yaml
kind: Secret
```

Создаем объект типа Secret.

```yaml
type: Opaque
```

*Opaque* — обычный пользовательский Secret с произвольными ключами и значениями.

```yaml
stringData:
  DB_USER: "demo_user"
  DB_PASSWORD: "demo_password"
```

*stringData* позволяет писать значения обычным текстом.

Kubernetes сам преобразует их в base64 внутри объекта Secret.

Если посмотреть Secret в YAML:

```bash
kubectl get secret hello-secret -n lab -o yaml
```

то увидим значения уже в поле data в base64.

## Deployment с ConfigMap и Secret

Файл:

```text
k8s/04-configmap-secret/deployment.yaml
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-config-deployment
  namespace: lab
  labels:
    app: hello-config
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-config
  template:
    metadata:
      labels:
        app: hello-config
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80

          env:
            - name: APP_NAME
              valueFrom:
                configMapKeyRef:
                  name: hello-config
                  key: APP_NAME

            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: hello-config
                  key: APP_ENV

            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: hello-config
                  key: LOG_LEVEL

            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: hello-secret
                  key: DB_USER

            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: hello-secret
                  key: DB_PASSWORD

          volumeMounts:
            - name: nginx-config
              mountPath: /etc/nginx/conf.d/default.conf
              subPath: nginx.conf

      volumes:
        - name: nginx-config
          configMap:
            name: hello-config
            items:
              - key: nginx.conf
                path: nginx.conf
```

## Как переменные попадают в контейнер

Пример из ConfigMap:

```yaml
- name: APP_NAME
  valueFrom:
    configMapKeyRef:
      name: hello-config
      key: APP_NAME
```

Это значит:

```text
Создай переменную окружения APP_NAME
и возьми значение из ConfigMap hello-config по ключу APP_NAME.
```

Пример из Secret:

```yaml
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: hello-secret
      key: DB_PASSWORD
```

Это значит:

```text
Создай переменную окружения DB_PASSWORD
и возьми значение из Secret hello-secret по ключу DB_PASSWORD.
```

## Как ConfigMap монтируется как файл

В контейнере есть блок:

```yaml
volumeMounts:
  - name: nginx-config
    mountPath: /etc/nginx/conf.d/default.conf
    subPath: nginx.conf
```

Это значит:

```text
Примонтировать один файл из volume nginx-config
в путь /etc/nginx/conf.d/default.conf
```

А сам volume описан ниже:

```yaml
volumes:
  - name: nginx-config
    configMap:
      name: hello-config
      items:
        - key: nginx.conf
          path: nginx.conf
```

Это значит:

```text
Создать volume из ConfigMap hello-config
и взять из него ключ nginx.conf как файл nginx.conf.
```

Итог:

```text
ConfigMap key nginx.conf
  ↓
volume nginx-config
  ↓
/etc/nginx/conf.d/default.conf внутри контейнера
```

Makefile для пятого шага
```Makefile
# 5th lab

.PHONY: apply-config-5
apply-config-5:
	kubectl apply -f k8s/04-configmap-secret/configmap.yaml
	kubectl apply -f k8s/04-configmap-secret/secret.yaml
	kubectl apply -f k8s/04-configmap-secret/deployment.yaml

.PHONY: get-configmap-5
get-configmap-5:
	kubectl get configmap -n lab

.PHONY: get-secret-5
get-secret-5:
	kubectl get secret -n lab

.PHONY: describe-configmap-5
describe-configmap-5:
	kubectl describe configmap hello-config -n lab

.PHONY: describe-secret-5
describe-secret-5:
	kubectl describe secret hello-secret -n lab

.PHONY: get-pods-5
get-pods-5:
	kubectl get pods -n lab -l app=hello-config -o wide

.PHONY: exec-env-5
exec-env-5:
	kubectl exec -it deploy/hello-config-deployment -n lab -- env

.PHONY: exec-shell-5
exec-shell-5:
	kubectl exec -it deploy/hello-config-deployment -n lab -- sh

.PHONY: forward-config-5
forward-config-5:
	kubectl port-forward deploy/hello-config-deployment 8081:80 -n lab

.PHONY: delete-config-5
delete-config-5:
	kubectl delete -f k8s/04-configmap-secret/deployment.yaml
	kubectl delete -f k8s/04-configmap-secret/secret.yaml
	kubectl delete -f k8s/04-configmap-secret/configmap.yaml
```

1. Применить ConfigMap, Secret и Deployment

```bash
make apply-config-5
```

Ожидаемый результат:

```text
configmap/hello-config created
secret/hello-secret created
deployment.apps/hello-config-deployment created
```

Если объекты уже были созданы:

```text
configured
```

или:

```text
unchanged
```

2. Проверить ConfigMap

```bash
make get-configmap-5
```

Ожидаемо:

```text
NAME               DATA   AGE
hello-config       4      ...
kube-root-ca.crt   1      ...
```

DATA 4 означает, что в ConfigMap четыре ключа:

```text
APP_NAME
APP_ENV
LOG_LEVEL
nginx.conf
```

3. Проверить Secret

```bash
make get-secret-5
```

Ожидаемо:

```text
NAME           TYPE     DATA   AGE
hello-secret   Opaque   2      ...
```

DATA 2 означает, что в Secret два ключа:

```text
DB_USER
DB_PASSWORD
```

4. Посмотреть ConfigMap подробно

```bash
make describe-configmap-5
```

Там можно увидеть обычные значения ConfigMap.

Важно: ConfigMap не скрывает данные.

5. Посмотреть Secret подробно

```bash
make describe-secret-5
```

В describe secret Kubernetes покажет ключи, но не покажет значения:

```text
Data
====
DB_PASSWORD:  13 bytes
DB_USER:      9 bytes
```

Это удобнее и безопаснее, чем выводить секреты в терминал.

6. Проверить Pod

```bash
make get-pods-5
```

Ожидаемо должно быть 2 Pod:

```text
NAME                                       READY   STATUS    RESTARTS   AGE
hello-config-deployment-xxxxxxxxx-abcde    1/1     Running   0          ...
hello-config-deployment-xxxxxxxxx-fghij    1/1     Running   0          ...
```

7. Проверить переменные окружения внутри контейнера

```bash
make exec-env-5
```

В выводе должны быть:

```text
APP_NAME=hello-api
APP_ENV=dev
LOG_LEVEL=debug
DB_USER=demo_user
DB_PASSWORD=demo_password
```

Так мы проверяем, что данные из ConfigMap и Secret попали внутрь контейнера как env-переменные.

8. Проверить nginx config через port-forward

```bash
make forward-config-5
```

В другом терминале:

```bash
curl http://localhost:8081
```

Ожидаемый ответ:

```text
Hello from ConfigMap nginx config
```

Это значит, что nginx использует конфигурационный файл из ConfigMap.

9. Посмотреть файл внутри контейнера

Зайти внутрь контейнера:

```bash
make exec-shell-5
```

Внутри выполнить:

```bash
cat /etc/nginx/conf.d/default.conf
```

Ожидаемо увидим конфиг из ConfigMap:

```text
server {
    listen 80;
    server_name localhost;

    location / {
        return 200 "Hello from ConfigMap nginx config\n";
    }
}
```

Выйти:

```bash
exit
```

## Важный нюанс про обновление ConfigMap

Если изменить ConfigMap и сделать:

```bash
kubectl apply -f k8s/04-configmap-secret/configmap.yaml
```

то объект ConfigMap в Kubernetes обновится.

Но приложение внутри Pod не всегда автоматически применит изменения.

Есть два варианта передачи ConfigMap:

1. Через env-переменные
2. Через mounted file

## Env-переменные

Если ConfigMap передан как env-переменные, то после изменения ConfigMap старые Pod не получат новые значения автоматически.

Нужно перезапустить Pod/Deployment:

```bash
kubectl rollout restart deploy/hello-config-deployment -n lab
```
## Mounted file

Если ConfigMap примонтирован как файл, Kubernetes может обновить файл внутри Pod через некоторое время.

Но само приложение должно перечитать этот файл.

Например, nginx сам по себе не всегда перечитывает конфиг без reload/restart.

Поэтому в production часто делают rollout restart после изменения ConfigMap.

## Secret тоже не Vault

Важно помнить:

```text
Secret в Kubernetes — это удобный объект для передачи чувствительных данных в Pod.
Но это не полноценное секрет-хранилище.
```

Почему:

```text
base64 — это не шифрование;
секреты могут попасть в env;
доступ к Secret регулируется RBAC;
нужно включать encryption at rest для etcd;
в production часто используют внешние secret manager.
```

Правильная production-схема часто выглядит так:

```text
Vault / Cloud Secret Manager
  ↓
External Secrets Operator
  ↓
Kubernetes Secret
  ↓
Pod
```

## Удалить объекты пятого шага

```bash
make delete-config-5
```

Удалятся:

```text
Deployment
Secret
ConfigMap
```

## Что важно понять после пятого шага

После этого шага нужно зафиксировать:

```text
ConfigMap хранит обычную конфигурацию.

Secret хранит чувствительные данные.

ConfigMap и Secret можно передавать в Pod как env-переменные.

ConfigMap и Secret можно монтировать в Pod как файлы.

Secret в Kubernetes хранит данные в base64, а base64 — это не шифрование.

После изменения ConfigMap/Secret Pod не всегда автоматически получает новые значения.

Для env-переменных нужен restart Pod/Deployment.

В production секреты часто приходят из Vault или External Secrets Operator.
```

## Мини-конспект

Схема передачи env:

```text
ConfigMap / Secret
  ↓
env в Deployment
  ↓
переменные окружения внутри контейнера
```

Схема передачи файла:

```text
ConfigMap
  ↓
volume
  ↓
volumeMount
  ↓
файл внутри контейнера
```

Главная мысль:

```text
Образ контейнера должен быть универсальным.
Конфигурация должна приходить извне.
```

Так один и тот же image можно запускать в разных окружениях:

```text
dev
stage
prod
```

с разными настройками.

# Что важно руками проверить

```bash
make apply-config-5
make get-configmap-5
make get-secret-5
make get-pods-5
make exec-env-5
make forward-config-5
```

В другом терминале:

```bash
curl http://localhost:8081
```

Ожидаемо:

```text
Hello from ConfigMap nginx config
```

Ключевая идея 5-го этапа:

```text
Deployment запускает приложение.
ConfigMap и Secret дают ему настройки.
```

То есть теперь у нас уже не просто nginx, а приложение, которое получает конфигурацию из Kubernetes.