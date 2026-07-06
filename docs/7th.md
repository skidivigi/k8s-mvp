# Седьмой шаг: Storage, Volume, PV и PVC

На этом шаге разбираем хранение данных в Kubernetes.

До этого мы запускали в основном stateless-приложения. Если Pod удалялся, Kubernetes создавал новый Pod, и это было нормально.

Но есть проблема:

```text
Pod временный.
Контейнер временный.
Файлы внутри контейнера тоже временные.
```

Если контейнер или Pod пересоздать, данные внутри файловой системы контейнера могут пропасть.

Для хранения данных используют volumes.

## Зачем нужен storage

Представим приложение, которое пишет файл:

```text
/usr/share/nginx/html/index.html
```

Если этот файл находится только внутри контейнера, то при пересоздании Pod данные могут исчезнуть.

Для stateful-приложений так нельзя.

Примеры stateful-приложений:

```text
PostgreSQL
Redis с persistence
Kafka
Elasticsearch
MinIO
Gitea
Nextcloud
```

Им нужно хранить данные независимо от жизни конкретного Pod.

## Главная идея

В Kubernetes Pod можно пересоздать, но данные должны жить отдельно.

```text
Pod умер
  ↓
Новый Pod создан
  ↓
Данные остались в volume
```

## Основные сущности

### Volume

`Volume` — это хранилище, которое монтируется внутрь Pod.

Пример:

```text
volume
  ↓
/usr/share/nginx/html внутри контейнера
```

Но volume бывает разный:

```text
emptyDir
hostPath
configMap
secret
persistentVolumeClaim
```

На этом шаге нас интересует `persistentVolumeClaim`.

### PersistentVolume

`PersistentVolume`, или `PV`, — это реальный кусок хранилища в Kubernetes.

Например:

```text
локальная директория node
NFS
Ceph
Longhorn
AWS EBS
GCP Persistent Disk
Azure Disk
```

PV — это ресурс кластера.

Он не принадлежит конкретному namespace.

### PersistentVolumeClaim

`PersistentVolumeClaim`, или `PVC`, — это запрос на хранилище.

Pod обычно не работает с PV напрямую.

Pod говорит:

```text
Мне нужен claim hello-pvc.
```

А PVC говорит:

```text
Мне нужно 1Gi хранилища с accessMode ReadWriteOnce.
```

Дальше Kubernetes связывает PVC с подходящим PV.

### StorageClass

`StorageClass` описывает тип хранилища и способ его создания.

Например:

```text
standard
local-path
longhorn
ceph-rbd
gp3
managed-csi
```

В kind обычно есть default StorageClass, который умеет динамически создавать PV.

Проверить:

```bash
make get-storageclass-7
```

## Схема

```text
Pod
  ↓ volumeMount
PVC
  ↓ binding
PV
  ↓ real storage
disk / local path / cloud disk
```

Или подробнее:

```text
Container path: /usr/share/nginx/html
  ↓
volumeMount
  ↓
volume
  ↓
PersistentVolumeClaim hello-pvc
  ↓
PersistentVolume
  ↓
real storage
```

## Файл PVC

Файл:

```text
k8s/06-storage/pvc.yaml
```

Содержимое:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: hello-pvc
  namespace: lab
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

## Разбор PVC

### `apiVersion`

```yaml
apiVersion: v1
```

`PersistentVolumeClaim` относится к базовой API-группе Kubernetes `v1`.

### `kind`

```yaml
kind: PersistentVolumeClaim
```

Создаем объект типа `PersistentVolumeClaim`.

Это запрос на постоянное хранилище.

### `metadata`

```yaml
metadata:
  name: hello-pvc
  namespace: lab
```

PVC создается в namespace `lab`.

Важно:

```text
PVC — namespaced object.
PV — cluster-wide object.
```

То есть PVC живет в namespace, а PV существует на уровне всего кластера.

### `accessModes`

```yaml
accessModes:
  - ReadWriteOnce
```

Access mode описывает, как volume может быть подключен.

Основные варианты:

```text
ReadWriteOnce   — volume может быть примонтирован для чтения/записи одной node
ReadOnlyMany    — volume может быть примонтирован только для чтения многими node
ReadWriteMany   — volume может быть примонтирован для чтения/записи многими node
ReadWriteOncePod — volume может быть примонтирован для чтения/записи одним Pod
```

В нашем случае:

```text
ReadWriteOnce
```

Это самый частый вариант для блочных дисков.

Например, cloud disk обычно нельзя одновременно примонтировать на запись к Pod на разных node.

### `resources.requests.storage`

```yaml
resources:
  requests:
    storage: 1Gi
```

Мы просим 1Gi хранилища.

Это не значит, что Kubernetes сам по себе создает диск из воздуха. Создание зависит от StorageClass и storage provisioner.

В kind default storage provisioner создаст локальное хранилище внутри node.

## Deployment с PVC

Файл:

```text
k8s/06-storage/deployment-with-volume.yaml
```

Содержимое:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-storage-deployment
  namespace: lab
  labels:
    app: hello-storage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-storage
  template:
    metadata:
      labels:
        app: hello-storage
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          volumeMounts:
            - name: hello-storage
              mountPath: /usr/share/nginx/html
      volumes:
        - name: hello-storage
          persistentVolumeClaim:
            claimName: hello-pvc
```

## Разбор Deployment

Основная новая часть:

```yaml
volumeMounts:
  - name: hello-storage
    mountPath: /usr/share/nginx/html
```

Это значит:

```text
Примонтировать volume hello-storage внутрь контейнера по пути:
/usr/share/nginx/html
```

Для nginx это директория, из которой он отдает HTML-файлы.

Дальше ниже описан сам volume:

```yaml
volumes:
  - name: hello-storage
    persistentVolumeClaim:
      claimName: hello-pvc
```

Это значит:

```text
Volume hello-storage должен использовать PVC hello-pvc.
```

Связка такая:

```text
volumeMounts.name = hello-storage
volumes.name      = hello-storage
claimName         = hello-pvc
```

## Почему replicas: 1

В этом примере указано:

```yaml
replicas: 1
```

Почему не 3?

Потому что PVC с `ReadWriteOnce` обычно нельзя безопасно использовать одновременно несколькими Pod на разных node.

Для stateful-приложений чаще используют:

```text
StatefulSet
```

А не обычный Deployment с несколькими репликами и одним PVC.

На этом шаге мы используем `Deployment` с одной репликой, чтобы не усложнять тему.

Позже можно отдельно разобрать `StatefulSet`.

## Makefile для седьмого шага

```makefile
# 7th lab - Storage

.PHONY: apply-storage-7
apply-storage-7:
	kubectl apply -f k8s/06-storage/pvc.yaml
	kubectl apply -f k8s/06-storage/deployment-with-volume.yaml

.PHONY: get-pvc-7
get-pvc-7:
	kubectl get pvc -n lab

.PHONY: describe-pvc-7
describe-pvc-7:
	kubectl describe pvc hello-pvc -n lab

.PHONY: get-pv-7
get-pv-7:
	kubectl get pv

.PHONY: get-storageclass-7
get-storageclass-7:
	kubectl get storageclass

.PHONY: get-pods-7
get-pods-7:
	kubectl get pods -n lab -l app=hello-storage -o wide

.PHONY: exec-storage-7
exec-storage-7:
	kubectl exec -it deploy/hello-storage-deployment -n lab -- sh

.PHONY: write-storage-7
write-storage-7:
	kubectl exec -it deploy/hello-storage-deployment -n lab -- sh -c 'echo "Hello from PVC" > /usr/share/nginx/html/index.html'

.PHONY: read-storage-7
read-storage-7:
	kubectl exec -it deploy/hello-storage-deployment -n lab -- cat /usr/share/nginx/html/index.html

.PHONY: forward-storage-7
forward-storage-7:
	kubectl port-forward deploy/hello-storage-deployment 8082:80 -n lab

.PHONY: restart-storage-7
restart-storage-7:
	kubectl rollout restart deploy/hello-storage-deployment -n lab

.PHONY: delete-storage-deploy-7
delete-storage-deploy-7:
	kubectl delete -f k8s/06-storage/deployment-with-volume.yaml

.PHONY: delete-storage-pvc-7
delete-storage-pvc-7:
	kubectl delete -f k8s/06-storage/pvc.yaml

.PHONY: delete-storage-7
delete-storage-7:
	kubectl delete -f k8s/06-storage/deployment-with-volume.yaml
	kubectl delete -f k8s/06-storage/pvc.yaml
```

## 1. Проверить StorageClass

Перед созданием PVC посмотрим, какой StorageClass есть в кластере:

```bash
make get-storageclass-7
```

Ожидаемо в kind будет что-то вроде:

```text
NAME                 PROVISIONER
standard (default)   rancher.io/local-path
```

Или похожий default provisioner.

Важно:

```text
default StorageClass используется, если в PVC явно не указан storageClassName.
```

В нашем PVC нет:

```yaml
storageClassName:
```

Поэтому Kubernetes использует default StorageClass.

## 2. Применить PVC и Deployment

```bash
make apply-storage-7
```

Ожидаемый результат:

```text
persistentvolumeclaim/hello-pvc created
deployment.apps/hello-storage-deployment created
```

## 3. Проверить PVC

```bash
make get-pvc-7
```

Ожидаемо:

```text
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
hello-pvc   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO            standard       ...
```

Главное:

```text
STATUS: Bound
```

Это значит, что Kubernetes нашел или создал PV и связал его с PVC.

Если статус:

```text
Pending
```

значит PVC пока не получил хранилище.

## 4. Проверить PV

```bash
make get-pv-7
```

Ожидаемо появится PV, связанный с нашим PVC:

```text
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM           STORAGECLASS
pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   1Gi        RWO            Delete           Bound    lab/hello-pvc   standard
```

Что важно:

```text
PV — cluster-wide объект.
PVC — объект в namespace lab.
```

Связка видна в поле:

```text
CLAIM: lab/hello-pvc
```

## 5. Проверить Pod

```bash
make get-pods-7
```

Ожидаемо:

```text
NAME                                        READY   STATUS    RESTARTS   AGE   NODE
hello-storage-deployment-xxxxxxxxx-xxxxx    1/1     Running   0          ...   platform-lab-worker
```

## 6. Записать файл в PVC

```bash
make write-storage-7
```

Эта команда запишет файл:

```text
/usr/share/nginx/html/index.html
```

с текстом:

```text
Hello from PVC
```

## 7. Прочитать файл из PVC

```bash
make read-storage-7
```

Ожидаемо:

```text
Hello from PVC
```

## 8. Проверить через nginx

Сделать port-forward:

```bash
make forward-storage-7
```

В другом терминале:

```bash
curl http://localhost:8082
```

Ожидаемо:

```text
Hello from PVC
```

Это значит:

```text
nginx отдает index.html, который лежит на PVC.
```

## 9. Проверить, что данные переживают restart Pod

Перезапустить Deployment:

```bash
make restart-storage-7
```

Проверить Pod:

```bash
make get-pods-7
```

Когда новый Pod будет Running, прочитать файл:

```bash
make read-storage-7
```

Ожидаемо:

```text
Hello from PVC
```

То есть Pod пересоздался, но данные остались.

Схема:

```text
Старый Pod удален
  ↓
Новый Pod создан
  ↓
PVC примонтирован снова
  ↓
index.html остался
```

## 10. Удалить только Deployment

```bash
make delete-storage-deploy-7
```

Проверить PVC:

```bash
make get-pvc-7
```

PVC останется.

Это важно:

```text
Deployment удален.
Pod удален.
PVC остался.
Данные продолжают существовать.
```

Можно снова применить Deployment:

```bash
kubectl apply -f k8s/06-storage/deployment-with-volume.yaml
```

И снова проверить:

```bash
make read-storage-7
```

Данные должны остаться.

## 11. Удалить PVC

```bash
make delete-storage-pvc-7
```

После удаления PVC связанный PV обычно тоже удаляется, если у него reclaim policy:

```text
Delete
```

Проверить:

```bash
make get-pv-7
```

Важно:

```text
Удаление PVC может привести к удалению реальных данных.
```

В production с этим нужно быть очень осторожным.

## Важный нюанс: Reclaim Policy

У PV есть `reclaimPolicy`.

Частые варианты:

```text
Delete — удалить PV и данные после удаления PVC
Retain — сохранить PV и данные после удаления PVC
```

В cloud-кластерах `Delete` может реально удалить cloud disk.

В production для критичных данных часто внимательно настраивают reclaim policy, backup и restore.

## Почему базы данных не всегда просто запускают в Deployment

Для stateless-приложений Deployment подходит хорошо.

Но для stateful-приложений есть проблемы:

```text
нужен стабильный identity Pod
нужны отдельные volume на каждую реплику
нужен понятный порядок запуска/остановки
нужен controlled rolling update
```

Для этого используют:

```text
StatefulSet
```

Например:

```text
postgres-0 → pvc-postgres-0
postgres-1 → pvc-postgres-1
postgres-2 → pvc-postgres-2
```

Deployment с одним PVC — нормален для учебного примера, но для баз данных чаще используют StatefulSet или operator.

## ConfigMap volume vs PVC volume

В прошлом шаге мы монтировали ConfigMap как файл:

```text
ConfigMap
  ↓
volume
  ↓
config file
```

Но это не хранилище данных приложения.

ConfigMap нужен для конфигурации.

PVC нужен для постоянных данных.

Коротко:

```text
ConfigMap volume — конфиги
Secret volume    — секреты
PVC volume       — данные приложения
```

## Что важно понять после седьмого шага

После этого шага нужно зафиксировать:

```text
Файлы внутри контейнера временные.

Pod может быть удален и создан заново.

Для постоянных данных используют PVC.

PVC — запрос на хранилище.

PV — реальное хранилище в кластере.

StorageClass описывает тип хранилища и provisioner.

Pod монтирует PVC через volume и volumeMount.

Данные на PVC переживают пересоздание Pod.

Удаление PVC может удалить реальные данные.

Для stateful-приложений обычно используют StatefulSet или operator.
```

## Мини-конспект

Схема:

```text
Deployment
  ↓
Pod
  ↓
volumeMount: /usr/share/nginx/html
  ↓
volume
  ↓
PVC hello-pvc
  ↓
PV
  ↓
real storage
```

Главная мысль:

```text
Pod — временный.
PVC — постоянное хранилище.
```

Именно поэтому данные должны жить не внутри контейнера, а на volume.

## Проверочный сценарий

```bash
make get-storageclass-7
make apply-storage-7
make get-pvc-7
make get-pv-7
make get-pods-7
make write-storage-7
make read-storage-7
```

Проверить через nginx:

```bash
make forward-storage-7
```

В другом терминале:

```bash
curl http://localhost:8082
```

Проверить сохранение данных после restart:

```bash
make restart-storage-7
make get-pods-7
make read-storage-7
```

Удалить только Deployment:

```bash
make delete-storage-deploy-7
make get-pvc-7
```

Удалить PVC:

```bash
make delete-storage-pvc-7
make get-pv-7
```
