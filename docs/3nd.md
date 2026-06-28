# Третий шаг: Deployment и ReplicaSet

На этом шаге переходим от напрямую созданного `Pod` к объекту `Deployment`.

В прошлом шаге мы создали `Pod` напрямую. Если такой `Pod` удалить, Kubernetes не создаст его заново.

В production обычно используют цепочку:

```text
Deployment → ReplicaSet → Pod
```

`Deployment` описывает желаемое состояние приложения, `ReplicaSet` следит за количеством Pod, а сами `Pod` уже запускают контейнеры.

## Что такое Deployment

`Deployment` — это Kubernetes-объект для управления stateless-приложениями.

Он отвечает за:

* создание Pod;
* поддержание нужного количества реплик;
* пересоздание Pod при удалении или падении;
* rolling update;
* rollback;
* масштабирование приложения.

Пример:

```text
Мы хотим 3 реплики nginx.

Deployment говорит Kubernetes:
"В namespace lab всегда должно быть 3 Pod с app=hello".

Если один Pod удалить, Kubernetes создаст новый.
```

## Что такое ReplicaSet

`ReplicaSet` — объект, который следит, чтобы количество Pod соответствовало нужному числу реплик.

Обычно мы не создаем `ReplicaSet` руками.

Его создает `Deployment`.

Цепочка такая:

```text
Deployment
  ↓
ReplicaSet
  ↓
Pod
  ↓
Container
```

## Манифест Deployment

Файл:

```text
k8s/02-deployment/deployment.yaml
```

Содержимое:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-deployment
  namespace: lab
  labels:
    app: hello
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hello
  template:
    metadata:
      labels:
        app: hello
    spec:
      containers:
        - name: hello-container
          image: nginx:1.27
          ports:
            - containerPort: 80
```

## Разбор манифеста

### `apiVersion`

```yaml
apiVersion: apps/v1
```

Для `Deployment` используется API-группа `apps/v1`.

Для сравнения, у обычного Pod было:

```yaml
apiVersion: v1
```

Потому что `Pod` — базовый объект Kubernetes, а `Deployment` относится к группе `apps`.

### `kind`

```yaml
kind: Deployment
```

Тип объекта — `Deployment`.

Мы говорим Kubernetes:

```text
Создай объект Deployment.
```

### `metadata`

```yaml
metadata:
  name: hello-deployment
  namespace: lab
  labels:
    app: hello
```

`metadata` описывает сам объект `Deployment`:

* `name` — имя Deployment;
* `namespace` — где создать объект;
* `labels` — метки самого Deployment.

Важно: эти labels относятся к Deployment, а не к Pod.

Labels для Pod задаются ниже в `spec.template.metadata.labels`.

### `replicas`

```yaml
spec:
  replicas: 3
```

Количество Pod, которое Kubernetes должен поддерживать.

В нашем случае Kubernetes должен держать 3 запущенных Pod.

Если один Pod удалить, будет создан новый.

Если указать `replicas: 5`, Kubernetes доведет количество Pod до 5.

Если указать `replicas: 1`, лишние Pod будут удалены.

### `selector`

```yaml
selector:
  matchLabels:
    app: hello
```

`selector` говорит Deployment/ReplicaSet, какими Pod он управляет.

В нашем случае он ищет Pod с label:

```text
app=hello
```

Очень важно, чтобы `selector.matchLabels` совпадал с labels в шаблоне Pod:

```yaml
template:
  metadata:
    labels:
      app: hello
```

Если они не совпадут, Deployment не сможет корректно управлять Pod.

### `template`

```yaml
template:
  metadata:
    labels:
      app: hello
    spec:
      containers:
        - name: hello-container
          image: nginx:1.27
          ports:
            - containerPort: 80
```

`template` — шаблон будущих Pod.

Deployment сам по себе контейнеры не запускает.

Он использует `template`, чтобы создавать Pod.

То есть эта часть почти как отдельный Pod-манифест, но без верхних полей:

```yaml
apiVersion
kind
metadata.name
```

Почему без `metadata.name`?

Потому что имена Pod будут генерироваться автоматически.

Пример:

```text
hello-deployment-7c9c4f8d7b-abc12
hello-deployment-7c9c4f8d7b-def34
hello-deployment-7c9c4f8d7b-ghi56
```

## Makefile для третьего шага

В `Makefile` можно добавить:

```makefile
# 3rd lab

.PHONY: apply-deploy-3
apply-deploy-3:
	kubectl apply -f k8s/02-deployment/deployment.yaml

.PHONY: get-deploy-3
get-deploy-3:
	kubectl get deploy -n lab

.PHONY: get-rs-3
get-rs-3:
	kubectl get rs -n lab

.PHONY: get-pods-3
get-pods-3:
	kubectl get pods -n lab -o wide

.PHONY: describe-deploy-3
describe-deploy-3:
	kubectl describe deploy hello-deployment -n lab

.PHONY: rollout-status-3
rollout-status-3:
	kubectl rollout status deploy/hello-deployment -n lab

.PHONY: scale-deploy-3
scale-deploy-3:
	kubectl scale deploy hello-deployment --replicas=5 -n lab

.PHONY: scale-deploy-back-3
scale-deploy-back-3:
	kubectl scale deploy hello-deployment --replicas=3 -n lab

.PHONY: delete-deploy-3
delete-deploy-3:
	kubectl delete -f k8s/02-deployment/deployment.yaml
```

## 1. Создать Deployment

```bash
make apply-deploy-3
```

Ожидаемый результат:

```text
deployment.apps/hello-deployment created
```

Если объект уже был создан ранее:

```text
deployment.apps/hello-deployment unchanged
```

или:

```text
deployment.apps/hello-deployment configured
```

## 2. Проверить Deployment

```bash
make get-deploy-3
```

Ожидаемый результат:

```text
NAME               READY   UP-TO-DATE   AVAILABLE   AGE
hello-deployment   3/3     3            3           30s
```

Что это значит:

```text
READY       — сколько Pod готовы
UP-TO-DATE  — сколько Pod соответствуют текущей версии шаблона
AVAILABLE   — сколько Pod доступны для трафика
AGE         — сколько времени существует Deployment
```

Если видишь:

```text
READY 3/3
```

значит все 3 реплики успешно запущены.

## 3. Проверить ReplicaSet

```bash
make get-rs-3
```

Ожидаемый результат:

```text
NAME                          DESIRED   CURRENT   READY   AGE
hello-deployment-xxxxxxxxxx    3         3         3       40s
```

Что это значит:

```text
DESIRED — сколько Pod должно быть
CURRENT — сколько Pod сейчас создано
READY   — сколько Pod готовы
```

ReplicaSet был создан автоматически.

Мы руками создавали только Deployment.

## 4. Проверить Pod

```bash
make get-pods-3
```

Ожидаемый результат:

```text
NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE
hello-deployment-xxxxxxxxxx-abcde   1/1     Running   0          1m    10.244.1.3   platform-lab-worker
hello-deployment-xxxxxxxxxx-fghij   1/1     Running   0          1m    10.244.2.4   platform-lab-worker2
hello-deployment-xxxxxxxxxx-klmno   1/1     Running   0          1m    10.244.1.5   platform-lab-worker
```

Теперь Pod имеют автосгенерированные имена.

Имя состоит из:

```text
hello-deployment - ReplicaSet hash - Pod suffix
```

Пример:

```text
hello-deployment-7c9c4f8d7b-abc12
```

Где:

```text
hello-deployment — имя Deployment
7c9c4f8d7b       — hash шаблона ReplicaSet
abc12            — уникальный suffix Pod
```

## 5. Посмотреть описание Deployment

```bash
make describe-deploy-3
```

Эта команда показывает:

* selector;
* количество replicas;
* стратегию обновления;
* шаблон Pod;
* conditions;
* events.

Внизу снова важно смотреть `Events`.

Пример:

```text
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  ...   deployment-controller  Scaled up replica set hello-deployment-... to 3
```

Это значит, что `Deployment Controller` создал или масштабировал `ReplicaSet`.

## 6. Проверить rollout status

```bash
make rollout-status-3
```

Ожидаемый результат:

```text
deployment "hello-deployment" successfully rolled out
```

`rollout status` показывает, завершилось ли развертывание Deployment.

Эта команда особенно полезна в CI/CD.

Например, после деплоя можно ждать, пока Kubernetes успешно обновит приложение.

## 7. Проверить самовосстановление Pod

Сначала получим список Pod:

```bash
make get-pods-3
```

Выбери один Pod и удали его:

```bash
kubectl delete pod <pod-name> -n lab
```

Например:

```bash
kubectl delete pod hello-deployment-7c9c4f8d7b-abc12 -n lab
```

Сразу после этого проверь Pod:

```bash
make get-pods-3
```

Ты увидишь, что удаленный Pod исчез, но Kubernetes создал новый.

Почему?

Потому что `Deployment` через `ReplicaSet` следит, чтобы всегда было 3 Pod.

Если стало 2, он создает третий.

### Что происходит внутри

```text
Ты удалил Pod
  ↓
ReplicaSet увидел: desired=3, current=2
  ↓
ReplicaSet создал новый Pod
  ↓
Scheduler выбрал node
  ↓
Kubelet запустил контейнер
```

Это ключевое отличие от напрямую созданного Pod.

## 8. Масштабировать Deployment до 5 Pod

```bash
make scale-deploy-3
```

Проверить:

```bash
make get-deploy-3
make get-pods-3
```

Ожидаемо станет 5 Pod.

Пример:

```text
READY 5/5
```

То есть мы изменили желаемое состояние:

```text
replicas: 3 → replicas: 5
```

Kubernetes создал недостающие Pod.

## 9. Вернуть обратно 3 Pod

```bash
make scale-deploy-back-3
```

Проверить:

```bash
make get-deploy-3
make get-pods-3
```

Ожидаемо снова будет 3 Pod.

Kubernetes удалит лишние Pod.

## 10. Удалить Deployment

```bash
make delete-deploy-3
```

Проверить:

```bash
make get-deploy-3
make get-rs-3
make get-pods-3
```

После удаления Deployment удалятся и связанные объекты:

```text
Deployment удален
  ↓
ReplicaSet удален
  ↓
Pod удалены
```

## Важный момент про selector и labels

Самая важная связка в Deployment:

```yaml
selector:
  matchLabels:
    app: hello

template:
  metadata:
    labels:
      app: hello
```

Она должна совпадать.

Deployment управляет только теми Pod, которые подходят под selector.

Если написать так:

```yaml
selector:
  matchLabels:
    app: hello

template:
  metadata:
    labels:
      app: nginx
```

то это будет ошибка или некорректная конфигурация.

Правило:

```text
selector.matchLabels должен совпадать с template.metadata.labels
```

## Чем Deployment лучше прямого Pod

Прямой Pod:

```text
Pod
```

Если удалить — исчезнет.

Deployment:

```text
Deployment → ReplicaSet → Pod
```

Если Pod удалить — будет создан новый.

Deployment дает:

* self-healing;
* scaling;
* rolling update;
* rollback;
* управление версиями;
* стабильную модель для production.

## Что важно понять после третьего шага

После этого шага нужно зафиксировать:

```text
Deployment — объект для управления приложением.

Deployment сам не запускает контейнеры напрямую.

Deployment создает ReplicaSet.

ReplicaSet создает и контролирует Pod.

replicas задает желаемое количество Pod.

selector определяет, какими Pod управляет Deployment.

template описывает, какие Pod нужно создавать.

Если Pod удалить, ReplicaSet создаст новый.

В production обычно используют Deployment, а не голый Pod.
```

## Мини-конспект

Когда мы выполняем:

```bash
make apply-deploy-3
```

фактически запускается:

```bash
kubectl apply -f k8s/02-deployment/deployment.yaml
```

Дальше цепочка такая:

```text
kubectl
  ↓
kube-apiserver
  ↓
etcd
  ↓
deployment-controller
  ↓
replicaset-controller
  ↓
scheduler
  ↓
kubelet на выбранной node
  ↓
container runtime
  ↓
container nginx
```

Главная разница с Pod:

```text
Pod — просто запущенный контейнер в Kubernetes.

Deployment — контроллер, который постоянно поддерживает нужное состояние приложения.
```

## Проверочный сценарий

Для закрепления выполни:

```bash
make apply-deploy-3
make get-deploy-3
make get-rs-3
make get-pods-3
make rollout-status-3
```

Потом удали один Pod вручную:

```bash
kubectl delete pod <pod-name> -n lab
```

И снова проверь:

```bash
make get-pods-3
```

Ты должен увидеть, что Kubernetes создал новый Pod.

Потом проверь масштабирование:

```bash
make scale-deploy-3
make get-pods-3
make scale-deploy-back-3
make get-pods-3
```

В конце удалить Deployment:

```bash
make delete-deploy-3
```
