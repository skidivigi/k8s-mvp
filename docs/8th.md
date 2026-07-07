# Восьмой шаг: StatefulSet

На этом шаге разбираем `StatefulSet`.

До этого мы уже прошли:

```text
Deployment → ReplicaSet → Pod
```

И разобрали `PVC`, чтобы данные переживали пересоздание Pod.

Теперь нужно понять, как запускать stateful-приложения, которым важны:

```text
стабильное имя Pod
стабильный network identity
отдельный PVC на каждую реплику
порядок запуска и остановки
```

Для этого в Kubernetes используют `StatefulSet`.

## Что такое StatefulSet

`StatefulSet` — это Kubernetes-объект для управления stateful-приложениями.

Он похож на `Deployment`, потому что тоже создает Pod, но дает больше гарантий для приложений с состоянием.

Примеры stateful-приложений:

```text
PostgreSQL
Redis
Kafka
Elasticsearch
ZooKeeper
MinIO
MongoDB
```

Им важно, чтобы реплики имели стабильные имена и свои постоянные данные.

## Главное отличие от Deployment

`Deployment` создает Pod со случайными именами:

```text
hello-deployment-7c9c4f8d7b-abcde
hello-deployment-7c9c4f8d7b-fghij
hello-deployment-7c9c4f8d7b-klmno
```

Эти Pod взаимозаменяемые.

Если один Pod удалить, Kubernetes создаст новый с другим именем.

`StatefulSet` создает Pod с предсказуемыми именами:

```text
nginx-stateful-0
nginx-stateful-1
nginx-stateful-2
```

Эти имена стабильные.

Если удалить `nginx-stateful-0`, Kubernetes создаст новый Pod снова с именем:

```text
nginx-stateful-0
```

## Схема

```text
StatefulSet nginx-stateful
  ├── Pod nginx-stateful-0
  │     └── PVC www-nginx-stateful-0
  │
  ├── Pod nginx-stateful-1
  │     └── PVC www-nginx-stateful-1
  │
  └── Pod nginx-stateful-2
        └── PVC www-nginx-stateful-2
```

У каждой реплики свой Pod и свой PVC.

Это ключевая идея `StatefulSet`.

## Что такое Headless Service

Для `StatefulSet` обычно создают `Headless Service`.

Обычный Service получает `ClusterIP`.

Headless Service создается с:

```yaml
clusterIP: None
```

Он не дает обычный балансирующий ClusterIP.

Вместо этого он нужен для стабильных DNS-записей Pod.

Например:

```text
nginx-stateful-0.nginx-stateful.lab.svc.cluster.local
nginx-stateful-1.nginx-stateful.lab.svc.cluster.local
nginx-stateful-2.nginx-stateful.lab.svc.cluster.local
```

Это важно для stateful-кластеров.

Например, Kafka, PostgreSQL, Redis или Elasticsearch могут знать конкретные реплики по стабильным DNS-именам.

## Файл Headless Service

Файл:

```text
k8s/07-statefulset/headless-service.yaml
```

Содержимое:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-stateful
  namespace: lab
  labels:
    app: nginx-stateful
spec:
  clusterIP: None
  selector:
    app: nginx-stateful
  ports:
    - name: http
      port: 80
      targetPort: 80
```

## Разбор Headless Service

### `clusterIP: None`

```yaml
clusterIP: None
```

Это делает Service headless.

То есть Kubernetes не создает обычный виртуальный ClusterIP для балансировки.

Вместо этого DNS будет возвращать адреса конкретных Pod.

### `selector`

```yaml
selector:
  app: nginx-stateful
```

Service выбирает Pod с label:

```text
app=nginx-stateful
```

Эти labels будут у Pod, которые создаст `StatefulSet`.

### `ports`

```yaml
ports:
  - name: http
    port: 80
    targetPort: 80
```

Service описывает порт `80`, который ведет к контейнерному порту `80`.

## Файл StatefulSet

Файл:

```text
k8s/07-statefulset/statefulset.yaml
```

Содержимое:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx-stateful
  namespace: lab
  labels:
    app: nginx-stateful
spec:
  serviceName: nginx-stateful
  replicas: 3
  selector:
    matchLabels:
      app: nginx-stateful
  template:
    metadata:
      labels:
        app: nginx-stateful
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - name: http
              containerPort: 80
          volumeMounts:
            - name: www
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: www
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
```

## Разбор StatefulSet

### `apiVersion`

```yaml
apiVersion: apps/v1
```

`StatefulSet`, как и `Deployment`, относится к API-группе `apps/v1`.

### `kind`

```yaml
kind: StatefulSet
```

Тип объекта — `StatefulSet`.

### `metadata`

```yaml
metadata:
  name: nginx-stateful
  namespace: lab
  labels:
    app: nginx-stateful
```

Имя StatefulSet:

```text
nginx-stateful
```

Именно от него будут формироваться имена Pod:

```text
nginx-stateful-0
nginx-stateful-1
nginx-stateful-2
```

### `serviceName`

```yaml
serviceName: nginx-stateful
```

Это имя headless Service, который связан со StatefulSet.

Важно: этот Service должен существовать.

Он нужен для стабильной сетевой идентичности Pod.

### `replicas`

```yaml
replicas: 3
```

Kubernetes должен поддерживать 3 Pod:

```text
nginx-stateful-0
nginx-stateful-1
nginx-stateful-2
```

### `selector`

```yaml
selector:
  matchLabels:
    app: nginx-stateful
```

StatefulSet управляет Pod с label:

```text
app=nginx-stateful
```

Как и у Deployment, selector должен совпадать с labels в template.

### `template`

```yaml
template:
  metadata:
    labels:
      app: nginx-stateful
```

Это шаблон Pod.

Все Pod, созданные StatefulSet, получат label:

```text
app=nginx-stateful
```

### `containers`

```yaml
containers:
  - name: nginx
    image: nginx:1.27
```

Внутри каждого Pod будет контейнер `nginx`.

### `volumeMounts`

```yaml
volumeMounts:
  - name: www
    mountPath: /usr/share/nginx/html
```

Каждый Pod примонтирует volume `www` в директорию:

```text
/usr/share/nginx/html
```

Для nginx это директория, из которой он отдает HTML-файлы.

### `volumeClaimTemplates`

```yaml
volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```

Это самый важный блок.

`volumeClaimTemplates` говорит StatefulSet:

```text
Для каждого Pod создай отдельный PVC по шаблону.
```

Если replicas = 3, Kubernetes создаст PVC:

```text
www-nginx-stateful-0
www-nginx-stateful-1
www-nginx-stateful-2
```

Формат имени:

```text
<volumeClaimTemplate-name>-<statefulset-name>-<ordinal>
```

В нашем случае:

```text
www-nginx-stateful-0
```

где:

```text
www            — имя volumeClaimTemplate
nginx-stateful — имя StatefulSet
0              — номер Pod
```

## Makefile для восьмого шага

```makefile
# 8th lab - StatefulSet

.PHONY: apply-statefulset-8
apply-statefulset-8:
	kubectl apply -f k8s/07-statefulset/headless-service.yaml
	kubectl apply -f k8s/07-statefulset/statefulset.yaml

.PHONY: get-statefulset-8
get-statefulset-8:
	kubectl get statefulset -n lab

.PHONY: get-sts-8
get-sts-8:
	kubectl get sts -n lab

.PHONY: describe-statefulset-8
describe-statefulset-8:
	kubectl describe statefulset nginx-stateful -n lab

.PHONY: get-pods-8
get-pods-8:
	kubectl get pods -n lab -l app=nginx-stateful -o wide

.PHONY: get-pvc-8
get-pvc-8:
	kubectl get pvc -n lab -l app=nginx-stateful

.PHONY: get-all-pvc-8
get-all-pvc-8:
	kubectl get pvc -n lab

.PHONY: get-headless-service-8
get-headless-service-8:
	kubectl get svc nginx-stateful -n lab

.PHONY: describe-headless-service-8
describe-headless-service-8:
	kubectl describe svc nginx-stateful -n lab

.PHONY: write-stateful-0-8
write-stateful-0-8:
	kubectl exec -it nginx-stateful-0 -n lab -- sh -c 'echo "Hello from nginx-stateful-0" > /usr/share/nginx/html/index.html'

.PHONY: write-stateful-1-8
write-stateful-1-8:
	kubectl exec -it nginx-stateful-1 -n lab -- sh -c 'echo "Hello from nginx-stateful-1" > /usr/share/nginx/html/index.html'

.PHONY: write-stateful-2-8
write-stateful-2-8:
	kubectl exec -it nginx-stateful-2 -n lab -- sh -c 'echo "Hello from nginx-stateful-2" > /usr/share/nginx/html/index.html'

.PHONY: read-stateful-0-8
read-stateful-0-8:
	kubectl exec -it nginx-stateful-0 -n lab -- cat /usr/share/nginx/html/index.html

.PHONY: read-stateful-1-8
read-stateful-1-8:
	kubectl exec -it nginx-stateful-1 -n lab -- cat /usr/share/nginx/html/index.html

.PHONY: read-stateful-2-8
read-stateful-2-8:
	kubectl exec -it nginx-stateful-2 -n lab -- cat /usr/share/nginx/html/index.html

.PHONY: delete-stateful-pod-0-8
delete-stateful-pod-0-8:
	kubectl delete pod nginx-stateful-0 -n lab

.PHONY: scale-statefulset-8
scale-statefulset-8:
	kubectl scale statefulset nginx-stateful --replicas=5 -n lab

.PHONY: scale-statefulset-back-8
scale-statefulset-back-8:
	kubectl scale statefulset nginx-stateful --replicas=3 -n lab

.PHONY: rollout-status-statefulset-8
rollout-status-statefulset-8:
	kubectl rollout status statefulset/nginx-stateful -n lab

.PHONY: delete-statefulset-8
delete-statefulset-8:
	kubectl delete -f k8s/07-statefulset/statefulset.yaml
	kubectl delete -f k8s/07-statefulset/headless-service.yaml

.PHONY: delete-statefulset-pvc-8
delete-statefulset-pvc-8:
	kubectl delete pvc -n lab -l app=nginx-stateful
```

## 1. Применить StatefulSet

```bash
make apply-statefulset-8
```

Ожидаемый результат:

```text
service/nginx-stateful created
statefulset.apps/nginx-stateful created
```

## 2. Проверить StatefulSet

```bash
make get-statefulset-8
```

Или коротко:

```bash
make get-sts-8
```

Ожидаемо:

```text
NAME             READY   AGE
nginx-stateful   3/3     1m
```

## 3. Проверить Pod

```bash
make get-pods-8
```

Ожидаемо:

```text
NAME               READY   STATUS    RESTARTS   AGE   NODE
nginx-stateful-0   1/1     Running   0          1m    platform-lab-worker
nginx-stateful-1   1/1     Running   0          1m    platform-lab-worker2
nginx-stateful-2   1/1     Running   0          1m    platform-lab-worker
```

Обрати внимание на имена:

```text
nginx-stateful-0
nginx-stateful-1
nginx-stateful-2
```

Они стабильные и предсказуемые.

## 4. Проверить PVC

```bash
make get-all-pvc-8
```

Ожидаемо появятся PVC:

```text
NAME                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
www-nginx-stateful-0   Bound    pvc-...                                    1Gi        RWO            standard
www-nginx-stateful-1   Bound    pvc-...                                    1Gi        RWO            standard
www-nginx-stateful-2   Bound    pvc-...                                    1Gi        RWO            standard
```

Главное:

```text
каждый Pod получил свой отдельный PVC
```

Связка:

```text
nginx-stateful-0 → www-nginx-stateful-0
nginx-stateful-1 → www-nginx-stateful-1
nginx-stateful-2 → www-nginx-stateful-2
```

## 5. Записать разные данные в разные Pod

Записать файл в первый Pod:

```bash
make write-stateful-0-8
```

Во второй:

```bash
make write-stateful-1-8
```

В третий:

```bash
make write-stateful-2-8
```

## 6. Прочитать данные

```bash
make read-stateful-0-8
make read-stateful-1-8
make read-stateful-2-8
```

Ожидаемо:

```text
Hello from nginx-stateful-0
Hello from nginx-stateful-1
Hello from nginx-stateful-2
```

Это показывает, что у каждой реплики свои данные.

## 7. Удалить один Pod

Удалим `nginx-stateful-0`:

```bash
make delete-stateful-pod-0-8
```

Проверим Pod:

```bash
make get-pods-8
```

Kubernetes создаст Pod снова с тем же именем:

```text
nginx-stateful-0
```

## 8. Проверить, что данные остались

Когда Pod снова будет `Running`, выполни:

```bash
make read-stateful-0-8
```

Ожидаемо:

```text
Hello from nginx-stateful-0
```

Это значит:

```text
Pod был пересоздан.
Имя осталось nginx-stateful-0.
PVC остался www-nginx-stateful-0.
Данные сохранились.
```

## 9. Масштабировать StatefulSet

Увеличить количество реплик до 5:

```bash
make scale-statefulset-8
```

Проверить:

```bash
make get-pods-8
make get-all-pvc-8
```

Появятся новые Pod:

```text
nginx-stateful-3
nginx-stateful-4
```

И новые PVC:

```text
www-nginx-stateful-3
www-nginx-stateful-4
```

Вернуть обратно 3 реплики:

```bash
make scale-statefulset-back-8
```

Проверить:

```bash
make get-pods-8
make get-all-pvc-8
```

Pod `nginx-stateful-3` и `nginx-stateful-4` будут удалены, но PVC обычно останутся.

Это важное поведение.

Kubernetes не удаляет PVC автоматически при уменьшении replicas, чтобы случайно не потерять данные.

## 10. Удалить StatefulSet

```bash
make delete-statefulset-8
```

Это удалит:

```text
StatefulSet
Headless Service
Pod
```

Но PVC обычно останутся.

Проверить:

```bash
make get-all-pvc-8
```

Почему PVC остаются?

Потому что Kubernetes осторожно относится к данным.

Удаление StatefulSet не должно автоматически уничтожать persistent data.

## 11. Удалить PVC StatefulSet

Если данные больше не нужны:

```bash
make delete-statefulset-pvc-8
```

Важно:

```text
Удаление PVC может удалить реальные данные.
```

В production с этим нужно быть очень осторожным.

## Ordered startup и shutdown

StatefulSet обычно создает Pod по порядку:

```text
nginx-stateful-0
  ↓
nginx-stateful-1
  ↓
nginx-stateful-2
```

И удаляет в обратном порядке:

```text
nginx-stateful-2
  ↓
nginx-stateful-1
  ↓
nginx-stateful-0
```

Это важно для кластеров, где порядок запуска имеет значение.

Например:

```text
сначала master/primary
потом replicas
сначала bootstrap node
потом остальные broker nodes
```

## Deployment vs StatefulSet

| Свойство                        |             Deployment |                 StatefulSet |
| ------------------------------- | ---------------------: | --------------------------: |
| Stateless-приложения            |                     Да |   Можно, но обычно не нужно |
| Stable Pod names                |                    Нет |                          Да |
| Stable DNS identity             |                    Нет |                          Да |
| Отдельный PVC на каждую реплику |      Нет автоматически |                          Да |
| Ordered startup/shutdown        |                    Нет |                          Да |
| Scaling                         |                     Да |                          Да |
| Rolling update                  |                     Да |                          Да |
| Основной кейс                   | API, frontend, workers | DB, brokers, clustered apps |

## Когда использовать Deployment

`Deployment` подходит для stateless-приложений:

```text
FastAPI
frontend
backend API
workers без локального state
nginx как простой reverse proxy
```

Если Pod можно удалить и заменить любым другим Pod без потери идентичности, это обычно `Deployment`.

## Когда использовать StatefulSet

`StatefulSet` подходит, когда важны:

```text
стабильное имя Pod
стабильный DNS
отдельные данные на каждую реплику
порядок запуска
порядок остановки
```

Примеры:

```text
postgres-0
postgres-1

kafka-0
kafka-1
kafka-2

redis-0
redis-1
redis-2
```

## Почему не один общий PVC на все реплики

Иногда возникает идея:

```text
Давайте дадим всем Pod один PVC.
```

Для многих storage backend это плохая идея.

Причины:

```text
ReadWriteOnce обычно не позволяет безопасно писать с разных node.
Приложения могут конфликтовать при записи в одни и те же файлы.
Для баз данных общий volume между несколькими Pod часто опасен.
```

Правильнее:

```text
один Pod → один PVC
```

Именно это удобно делает `StatefulSet` через `volumeClaimTemplates`.

## Что важно понять после восьмого шага

После этого шага нужно зафиксировать:

```text
StatefulSet нужен для stateful-приложений.

StatefulSet дает стабильные имена Pod.

Pod называются по порядку: name-0, name-1, name-2.

Для StatefulSet обычно нужен Headless Service.

Headless Service дает стабильные DNS-имена Pod.

volumeClaimTemplates создает отдельный PVC для каждого Pod.

Удаление Pod не удаляет его PVC.

Удаление StatefulSet обычно не удаляет PVC.

При scale down PVC тоже обычно остаются.

Для баз данных и брокеров часто используют StatefulSet или operator.
```

## Мини-конспект

`Deployment`:

```text
Deployment
  ↓
ReplicaSet
  ↓
случайные Pod names
  ↓
stateless workload
```

`StatefulSet`:

```text
StatefulSet
  ↓
nginx-stateful-0 → www-nginx-stateful-0
nginx-stateful-1 → www-nginx-stateful-1
nginx-stateful-2 → www-nginx-stateful-2
  ↓
stateful workload
```

Главная мысль:

```text
Deployment управляет одинаковыми взаимозаменяемыми Pod.

StatefulSet управляет Pod с постоянной идентичностью и своими данными.
```

## Проверочный сценарий

```bash
make apply-statefulset-8
make get-sts-8
make get-pods-8
make get-all-pvc-8
```

Записать данные:

```bash
make write-stateful-0-8
make write-stateful-1-8
make write-stateful-2-8
```

Прочитать данные:

```bash
make read-stateful-0-8
make read-stateful-1-8
make read-stateful-2-8
```

Удалить Pod и проверить восстановление:

```bash
make delete-stateful-pod-0-8
make get-pods-8
make read-stateful-0-8
```

Проверить scale:

```bash
make scale-statefulset-8
make get-pods-8
make get-all-pvc-8

make scale-statefulset-back-8
make get-pods-8
make get-all-pvc-8
```

Удалить StatefulSet:

```bash
make delete-statefulset-8
make get-all-pvc-8
```

Удалить PVC:

```bash
make delete-statefulset-pvc-8
```
