# Второй шаг: первый Pod

На этом шаге создаем первый `Pod` в namespace `lab`, смотрим его состояние, описание, логи, заходим внутрь контейнера и проверяем доступ к `nginx` через `port-forward`.

## Что такое Pod

`Pod` — минимальная единица запуска приложения в Kubernetes.

Обычно внутри `Pod` находится один контейнер, но технически контейнеров может быть несколько.

`Pod` получает:

* собственный IP внутри кластера;
* namespace;
* labels;
* containers;
* volumes;
* настройки запуска.

Важно: `Pod` — временная сущность. Его IP может измениться, а при удалении напрямую созданный `Pod` не будет восстановлен автоматически.

## Манифест Pod

Файл:

```text
k8s/01-pod/pod.yaml
```

Содержимое:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-pod
  namespace: lab
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

```yaml
apiVersion: v1
```

Версия Kubernetes API для объекта `Pod`.

```yaml
kind: Pod
```

Тип Kubernetes-объекта. Здесь мы говорим Kubernetes создать объект типа `Pod`.

```yaml
metadata:
  name: hello-pod
  namespace: lab
  labels:
    app: hello
```

`metadata` — служебная информация об объекте:

* `name` — имя Pod;
* `namespace` — namespace, где будет создан Pod;
* `labels` — метки объекта.

Метки нужны для поиска объектов и связи между Kubernetes-ресурсами. Позже `Service` будет находить `Pod` именно по label.

```yaml
spec:
  containers:
    - name: hello-container
      image: nginx:1.27
      ports:
        - containerPort: 80
```

`spec` — желаемое состояние объекта.

Здесь мы описываем, что внутри `Pod` должен быть контейнер:

* с именем `hello-container`;
* из образа `nginx:1.27`;
* с портом `80` внутри контейнера.

## Makefile для второго шага

В `Makefile` добавлены команды:

```makefile
# 2nd lab

.PHONY: apply-pod
apply-pod:
	kubectl apply -f k8s/01-pod/pod.yaml

.PHONY: get-pod-2
get-pod-2:
	kubectl get pods -n lab

.PHONY: describe-pod-2
describe-pod-2:
	kubectl describe pod hello-pod -n lab

.PHONY: logs-pod-2
logs-pod-2:
	kubectl logs hello-pod -n lab

.PHONY: exec-pod-2
exec-pod-2:
	kubectl exec -it hello-pod -n lab -- sh

.PHONY: forward-pod-2
forward-pod-2:
	kubectl port-forward pod/hello-pod 8080:80 -n lab

.PHONY: delete-pod-2
delete-pod-2:
	kubectl delete -f k8s/01-pod/pod.yaml
# or
# kubectl delete pod hello-pod -n lab
```

## 1. Создать Pod

```bash
make apply-pod
```

Ожидаемый результат:

```text
pod/hello-pod created
```

Если Pod уже был создан ранее, будет:

```text
pod/hello-pod unchanged
```

или:

```text
pod/hello-pod configured
```

## 2. Проверить состояние Pod

```bash
make get-pod-2
```

Ожидаемый результат:

```text
NAME        READY   STATUS    RESTARTS   AGE
hello-pod   1/1     Running   0          10s
```

Значения:

* `READY 1/1` — один контейнер из одного готов;
* `STATUS Running` — Pod запущен;
* `RESTARTS 0` — контейнер не перезапускался;
* `AGE` — сколько времени Pod существует.

## 3. Посмотреть подробное описание Pod

Подробнее разбор вывода команды смотри в разделе:  
[Подробный разбор вывода kubectl describe pod](#подробный-разбор-вывода-kubectl-describe-pod)

```bash
make describe-pod-2
```

Эта команда показывает подробную информацию о Pod:

* namespace;
* labels;
* node, на которой запущен Pod;
* IP-адрес Pod;
* контейнеры;
* image;
* ports;
* events;
* ошибки запуска, если они есть.

Особенно важен блок `Events`.

Пример:

```text
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  ...   default-scheduler  Successfully assigned lab/hello-pod to platform-lab-worker
  Normal  Pulling    ...   kubelet            Pulling image "nginx:1.27"
  Normal  Pulled     ...   kubelet            Successfully pulled image
  Normal  Created    ...   kubelet            Created container hello-container
  Normal  Started    ...   kubelet            Started container hello-container
```

По этому блоку видно, как Kubernetes запускал Pod:

```text
Scheduled → Pulling → Pulled → Created → Started
```

## 4. Посмотреть логи Pod

```bash
make logs-pod-2
```

Так как внутри Pod запущен `nginx`, логов может быть мало или вообще не быть, пока в него не пришел HTTP-запрос.

## 5. Зайти внутрь контейнера

```bash
make exec-pod-2
```

После входа внутрь контейнера можно выполнить:

```bash
hostname
nginx -v
ls
```

Выйти из контейнера:

```bash
exit
```

Важно: команда `exec` запускает shell внутри контейнера, но не подключается к ноде Kubernetes. Мы попадаем именно внутрь контейнера `hello-container`.

## 6. Проверить nginx через port-forward

Сам Pod напрямую с хоста недоступен.

Для временной проверки можно пробросить порт:

```bash
make forward-pod-2
```

Команда пробросит:

```text
localhost:8080 → hello-pod:80
```

В другом терминале выполнить:

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

После запроса можно снова посмотреть логи:

```bash
make logs-pod-2
```

Теперь в логах nginx должен появиться HTTP-запрос.

## 7. Удалить Pod

```bash
make delete-pod-2
```

Проверить, что Pod удалился:

```bash
make get-pod-2
```

Если Pod удален, в namespace `lab` больше не будет `hello-pod`.

## Важный момент

Если удалить напрямую созданный `Pod`, он не появится заново.

Почему?

Потому что мы создали именно `Pod`:

```text
Pod
```

А не более высокий объект, который контролирует количество реплик.

В production обычно используют такую цепочку:

```text
Deployment → ReplicaSet → Pod
```

`Deployment` следит, чтобы нужное количество Pod всегда было запущено.

Если Pod упал или был удален, `Deployment` через `ReplicaSet` создаст новый Pod.

А напрямую созданный `Pod` никто не восстанавливает.

## Что важно понять после второго шага

После этого шага нужно зафиксировать:

```text
Pod — минимальная единица запуска приложения в Kubernetes.

Pod обычно содержит один контейнер.

Pod получает IP внутри кластера.

Pod создается в конкретном namespace.

Labels нужны для поиска и связи объектов.

kubectl describe показывает жизненный цикл и ошибки Pod.

kubectl logs показывает stdout/stderr контейнера.

kubectl exec позволяет зайти внутрь контейнера.

kubectl port-forward временно пробрасывает порт с localhost в Pod.

Напрямую созданный Pod не восстанавливается после удаления.
```

## Мини-конспект

Когда мы выполняем:

```bash
make apply-pod
```

фактически запускается:

```bash
kubectl apply -f k8s/01-pod/pod.yaml
```

Дальше цепочка такая:

```text
kubectl
  ↓
kube-apiserver
  ↓
etcd
  ↓
scheduler
  ↓
kubelet на выбранной node
  ↓
container runtime
  ↓
container nginx
```

На этом шаге Kubernetes запустил контейнер `nginx`, но еще не создал нормальный production-механизм управления приложением.

Следующий шаг — `Deployment` и `ReplicaSet`.


## Подробный разбор вывода `kubectl describe pod`

Команда:

```bash
make describe-pod-2
```

фактически выполняет:

```bash
kubectl describe pod hello-pod -n lab
```

Она показывает подробное состояние `Pod`, его контейнеров, volumes, условий готовности и событий запуска.

Пример вывода:

```text
Name:             hello-pod
Namespace:        lab
Priority:         0
Service Account:  default
Node:             platform-lab-worker2/172.19.0.3
Start Time:       Sun, 28 Jun 2026 10:03:42 +0300
Labels:           app=hello
Annotations:      <none>
Status:           Running
IP:               10.244.2.2
```

### Основная информация о Pod

```text
Name: hello-pod
```

Имя Pod. Оно берется из манифеста:

```yaml
metadata:
  name: hello-pod
```

---

```text
Namespace: lab
```

Namespace, в котором создан Pod.

В нашем случае Pod создан в namespace `lab`:

```yaml
metadata:
  namespace: lab
```

---

```text
Priority: 0
```

Приоритет Pod.

Приоритет влияет на то, какие Pod Kubernetes может вытеснить первыми, если на node не хватает ресурсов.

У нас приоритет обычный — `0`.

---

```text
Service Account: default
```

ServiceAccount, от имени которого работает Pod.

Мы явно не указывали ServiceAccount, поэтому Kubernetes использовал стандартный:

```text
default
```

ServiceAccount нужен, когда Pod должен обращаться к Kubernetes API или другим ресурсам кластера с определенными правами.

---

```text
Node: platform-lab-worker2/172.19.0.3
```

Node, на которую scheduler посадил Pod.

В нашем случае Pod запущен на worker-ноде:

```text
platform-lab-worker2
```

IP `172.19.0.3` — это IP node внутри Docker-сети kind.

---

```text
Start Time: Sun, 28 Jun 2026 10:03:42 +0300
```

Время, когда Pod начал создаваться.

---

```text
Labels: app=hello
```

Labels — метки Pod.

Они берутся из манифеста:

```yaml
labels:
  app: hello
```

Labels нужны, чтобы другие Kubernetes-объекты могли находить этот Pod.

Например, позже `Service` будет искать Pod по selector:

```yaml
selector:
  app: hello
```

---

```text
Annotations: <none>
```

Annotations — дополнительные служебные метаданные.

В отличие от labels, annotations обычно не используются для выборки объектов, а хранят дополнительную информацию для контроллеров, инструментов и аддонов.

У нас annotations нет.

---

```text
Status: Running
```

Текущий статус Pod.

`Running` означает, что Pod назначен на node, контейнер создан и запущен.

---

```text
IP: 10.244.2.2
```

Внутренний IP Pod внутри Kubernetes-кластера.

Этот IP выдается CNI-плагином.

Важно: IP Pod временный. Если Pod удалить и создать заново, IP может измениться.

Поэтому в Kubernetes обычно не обращаются к Pod напрямую по IP, а используют `Service`.

---

```text
IPs:
  IP: 10.244.2.2
```

Список IP-адресов Pod.

Обычно здесь один IP. В некоторых сетевых конфигурациях может быть несколько адресов, например IPv4 и IPv6.

## Блок Containers

```text
Containers:
  hello-container:
    Container ID:   containerd://3c697fddfc4057082690608410eced8e1cf0234797b07db4434983b6365e1e18
    Image:          nginx:1.27
    Image ID:       docker.io/library/nginx@sha256:...
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Sun, 28 Jun 2026 10:03:53 +0300
    Ready:          True
    Restart Count:  0
    Environment:    <none>
```

Этот блок описывает контейнеры внутри Pod.

В нашем случае контейнер один:

```text
hello-container
```

---

```text
Container ID: containerd://...
```

ID реально созданного контейнера в container runtime.

В kind используется containerd, поэтому ID начинается с:

```text
containerd://
```

Это уже не Kubernetes-абстракция, а конкретный контейнер, который запущен runtime'ом на node.

---

```text
Image: nginx:1.27
```

Docker image, из которого запущен контейнер.

Он берется из манифеста:

```yaml
image: nginx:1.27
```

---

```text
Image ID: docker.io/library/nginx@sha256:...
```

Точный digest образа.

`nginx:1.27` — это tag.

А `sha256:...` — конкретная неизменяемая версия образа.

Это важно, потому что tag теоретически может быть перезаписан, а digest всегда указывает на конкретный образ.

---

```text
Port: 80/TCP
```

Порт контейнера, который мы указали в манифесте:

```yaml
ports:
  - containerPort: 80
```

Важно: `containerPort` сам по себе не открывает приложение наружу.

Он скорее документирует, какой порт слушает контейнер. Для доступа нужен `Service`, `Ingress` или `port-forward`.

---

```text
Host Port: 0/TCP
```

HostPort не используется.

`0` означает, что порт контейнера не проброшен напрямую на порт node.

Это нормально. В Kubernetes обычно не используют `hostPort` для обычных приложений.

---

```text
State: Running
```

Контейнер сейчас запущен.

Другие возможные состояния:

```text
Waiting
Running
Terminated
```

---

```text
Started: Sun, 28 Jun 2026 10:03:53 +0300
```

Время фактического старта контейнера.

Оно может отличаться от `Start Time` Pod, потому что сначала Pod назначается на node, потом kubelet скачивает image, создает контейнер и только потом запускает его.

---

```text
Ready: True
```

Контейнер считается готовым.

Если бы у нас была `readinessProbe`, Kubernetes определял бы готовность по ней.

Сейчас readinessProbe нет, поэтому контейнер считается готовым после успешного запуска.

---

```text
Restart Count: 0
```

Количество перезапусков контейнера.

`0` означает, что контейнер ни разу не падал.

Если приложение падает, это число будет расти.

---

```text
Environment: <none>
```

В контейнер не переданы переменные окружения.

Позже мы добавим их через:

* `ConfigMap`;
* `Secret`;
* `env`;
* `envFrom`.

## Mounts

```text
Mounts:
  /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-hv7n7 (ro)
```

Kubernetes автоматически примонтировал внутрь Pod служебные данные ServiceAccount.

Путь:

```text
/var/run/secrets/kubernetes.io/serviceaccount
```

Внутри обычно находятся:

```text
token
ca.crt
namespace
```

Они нужны, чтобы контейнер мог обращаться к Kubernetes API от имени своего ServiceAccount.

`ro` означает read-only, то есть только для чтения.

Даже если мы явно не просили этот volume, Kubernetes добавил его автоматически.

## Conditions

```text
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       True 
  ContainersReady             True 
  PodScheduled                True 
```

Conditions показывают состояние Pod по ключевым этапам жизненного цикла.

---

```text
PodScheduled True
```

Pod успешно назначен на node.

Scheduler выбрал node:

```text
platform-lab-worker2
```

---

```text
Initialized True
```

Pod успешно прошел инициализацию.

Если бы были initContainers, Kubernetes сначала выполнил бы их, а потом запустил основной контейнер.

---

```text
PodReadyToStartContainers True
```

Pod готов к запуску контейнеров.

Это означает, что sandbox для Pod подготовлен, сеть настроена, и kubelet может запускать контейнеры.

---

```text
ContainersReady True
```

Все контейнеры внутри Pod готовы.

У нас один контейнер, и он готов.

---

```text
Ready True
```

Pod готов принимать трафик.

Важно: именно `Ready=True` влияет на то, будет ли Pod попадать в endpoints у Service.

Если Pod не Ready, Service не должен отправлять на него трафик.

## Volumes

```text
Volumes:
  kube-api-access-hv7n7:
    Type:                    Projected
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
```

Это автоматически созданный Kubernetes volume.

Он называется примерно так:

```text
kube-api-access-xxxxx
```

Название генерируется автоматически.

---

```text
Type: Projected
```

`Projected` volume объединяет данные из нескольких источников в один volume.

В нашем случае туда попадают:

* ServiceAccount token;
* CA certificate Kubernetes API;
* информация через Downward API.

---

```text
TokenExpirationSeconds: 3607
```

Время жизни service account token.

Kubernetes использует временные токены, которые могут обновляться.

---

```text
ConfigMapName: kube-root-ca.crt
```

ConfigMap с CA-сертификатом Kubernetes-кластера.

Он нужен контейнеру, чтобы доверять Kubernetes API server при HTTPS-соединении.

---

```text
DownwardAPI: true
```

Downward API позволяет передавать внутрь Pod информацию о самом Pod.

Например:

* namespace;
* имя Pod;
* labels;
* annotations;
* limits/requests.

## QoS Class

```text
QoS Class: BestEffort
```

QoS Class — класс качества обслуживания Pod.

У нас `BestEffort`, потому что мы не указали:

```yaml
resources:
  requests:
  limits:
```

То есть Pod не попросил гарантированные CPU/RAM и не получил лимитов.

Основные QoS-классы:

```text
BestEffort
Burstable
Guaranteed
```

Коротко:

```text
BestEffort — нет requests и limits
Burstable  — requests/limits указаны частично или не равны
Guaranteed — requests и limits указаны и равны для CPU/RAM
```

Важно: при нехватке ресурсов Kubernetes в первую очередь будет вытеснять Pod с QoS `BestEffort`.

Позже мы отдельно разберем `requests` и `limits`.

## Node-Selectors

```text
Node-Selectors: <none>
```

Мы не указывали, на какую node нужно посадить Pod.

Поэтому scheduler сам выбрал подходящую node.

Позже это можно контролировать через:

* `nodeSelector`;
* `nodeAffinity`;
* `taints`;
* `tolerations`.

## Tolerations

```text
Tolerations:
  node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
  node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
```

Tolerations позволяют Pod запускаться или временно оставаться на node с определенными taints.

Эти tolerations Kubernetes добавляет автоматически.

Они означают:

```text
Если node временно стала NotReady или Unreachable,
не удалять Pod сразу, а подождать 300 секунд.
```

То есть Kubernetes дает node время восстановиться.

## Events

```text
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  78s   default-scheduler  Successfully assigned lab/hello-pod to platform-lab-worker2
  Normal  Pulling    77s   kubelet            Pulling image "nginx:1.27"
  Normal  Pulled     67s   kubelet            Successfully pulled image "nginx:1.27" in 10.358s
  Normal  Created    67s   kubelet            Container created
  Normal  Started    67s   kubelet            Container started
```

Events — один из самых полезных блоков при диагностике.

Он показывает, что Kubernetes делал с Pod.

---

```text
Scheduled
```

Scheduler выбрал node для Pod.

В нашем случае:

```text
platform-lab-worker2
```

---

```text
Pulling
```

Kubelet начал скачивать image:

```text
nginx:1.27
```

---

```text
Pulled
```

Image успешно скачан.

В выводе видно, сколько заняло скачивание:

```text
10.358s
```

---

```text
Created
```

Kubelet создал контейнер через container runtime.

---

```text
Started
```

Контейнер был запущен.

Итоговая цепочка запуска:

```text
Scheduled
  ↓
Pulling
  ↓
Pulled
  ↓
Created
  ↓
Started
```

## Как читать этот вывод при troubleshooting

Если Pod не запускается, первым делом смотрим:

```bash
make describe-pod-2
```

И проверяем:

```text
Status
Containers → State
Containers → Ready
Containers → Restart Count
Conditions
Events
```

Частые проблемы:

```text
ImagePullBackOff       — Kubernetes не может скачать image
ErrImagePull           — ошибка при скачивании image
CrashLoopBackOff       — контейнер запускается и сразу падает
Pending                — Pod не может быть назначен на node
OOMKilled              — контейнер убит из-за нехватки памяти
CreateContainerConfigError — ошибка конфигурации контейнера
```

Для диагностики обычно используют связку:

```bash
kubectl get pods -n lab
kubectl describe pod hello-pod -n lab
kubectl logs hello-pod -n lab
```

В нашем Makefile это:

```bash
make get-pod-2
make describe-pod-2
make logs-pod-2
```

## Главное по выводу describe

В нашем случае Pod запущен успешно:

```text
Status: Running
Ready: True
Restart Count: 0
QoS Class: BestEffort
Events: Scheduled → Pulling → Pulled → Created → Started
```

Это значит:

```text
Pod успешно создан.
Scheduler назначил его на worker-node.
Kubelet скачал image nginx.
Container runtime создал контейнер.
Контейнер стартовал.
Pod готов к работе.
```
