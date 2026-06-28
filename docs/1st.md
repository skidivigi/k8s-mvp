# Первый запуск kind-кластера

На этом шаге создаем локальный Kubernetes-кластер через `kind`, проверяем его состояние и создаем базовые namespace для дальнейшей работы.

## Конфигурация kind-кластера

Файл `kind/cluster.yaml` описывает локальный Kubernetes-кластер, который будет создан через `kind`.

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: platform-lab
```

1. *kind: Cluster* — тип объекта в конфигурации kind;
2. *apiVersion: kind.x-k8s.io/v1alpha4* — версия схемы конфигурации kind;
3. *name: platform-lab* — имя локального кластера.

Это не Kubernetes-манифест для Pod или Deployment, а конфигурация самого kind-кластера.

## 1. Создаем кластер

После создания файлов запускаем:

```bash
# Создаем кластер в kind
make create
```

Эта команда использует файл:

```text
kind/cluster.yaml
```

И поднимает локальный Kubernetes-кластер внутри Docker-контейнеров.

## 2. Проверяем состояние нод

```bash
# Проверяем состояние нод кластера
make nodes
```

Ожидаем увидеть примерно такой вывод:

```text
NAME                         STATUS   ROLES           AGE   VERSION
platform-lab-control-plane   Ready    control-plane   ...
platform-lab-worker          Ready    <none>          ...
platform-lab-worker2         Ready    <none>          ...
```

Здесь:

```text
platform-lab-control-plane — управляющая нода Kubernetes
platform-lab-worker        — worker-нода
platform-lab-worker2       — вторая worker-нода
```

## 3. Проверяем системные Pod

Можно посмотреть, какие Pod уже запущены в кластере:

```bash
make pods
```

Ожидаемо там будут системные компоненты Kubernetes:

```text
kube-system/coredns
kube-system/etcd
kube-system/kube-apiserver
kube-system/kube-controller-manager
kube-system/kube-scheduler
kube-system/kube-proxy
```

Это базовые компоненты, без которых Kubernetes-кластер не работает.

## 4. Применяем namespace

Перед созданием своих приложений создадим отдельные namespace.

```bash
# Создаем учебные namespace
make apply-ns
```

Будут созданы:

```text
lab            — namespace для учебных приложений
observability  — namespace для мониторинга и логов
argocd         — namespace для GitOps
ingress-nginx  — namespace для Ingress Controller
```

## 5. Проверяем namespace

```bash
make ns
```

Ожидаем увидеть примерно:

```text
NAME              STATUS   AGE
argocd            Active   ...
default           Active   ...
ingress-nginx     Active   ...
kube-node-lease   Active   ...
kube-public       Active   ...
kube-system       Active   ...
lab               Active   ...
observability     Active   ...
```

## Что нужно понять после первого шага

После этого этапа важно зафиксировать:

```text
kind — инструмент для запуска Kubernetes локально в Docker

cluster — весь Kubernetes-кластер

node — машина внутри кластера

control-plane — управляющая часть Kubernetes

worker — нода для запуска пользовательских Pod

namespace — логическое разделение ресурсов внутри кластера

kubectl — CLI для общения с kube-apiserver
```

## Мини-конспект

```text
kubectl не управляет Pod напрямую.

kubectl отправляет запрос в kube-apiserver.

kube-apiserver сохраняет желаемое состояние в etcd.

controller-manager и scheduler смотрят на это состояние.

scheduler выбирает ноду.

kubelet на выбранной ноде запускает контейнер через container runtime.
```

То есть цепочка выглядит так:

```text
kubectl
  ↓
kube-apiserver
  ↓
etcd
  ↓
controller-manager / scheduler
  ↓
kubelet
  ↓
container runtime
  ↓
container
```

Именно эту цепочку дальше будем повторять на каждом Kubernetes-объекте.

## Главное

На этом шаге мы еще не запускали свое приложение.

Мы только подготовили базовую платформу:

```text
Docker
  └── kind
        └── Kubernetes cluster
              ├── control-plane
              ├── worker
              └── worker
```

И создали namespace, чтобы дальше аккуратно раскладывать компоненты по зонам ответственности.

## Что такое Namespace

`Namespace` — это логическое разделение ресурсов внутри Kubernetes-кластера.

Он помогает разделять приложения, окружения и системные компоненты:

```text
lab            — учебные приложения
observability  — мониторинг и логи
argocd         — GitOps
ingress-nginx  — Ingress Controller
```

Namespace влияет на видимость объектов при работе через kubectl.

Например:

```bash
kubectl get pods -n lab
```

покажет Pod только из namespace lab.

А команда:

```bash
kubectl get pods -A
```

покажет Pod во всех namespace.

Важно: namespace сам по себе не является полноценной изоляцией безопасности.

Pod из разных namespace по умолчанию могут общаться друг с другом через Service/DNS, например:

```text
hello-api.lab.svc.cluster.local
```

Для реальной изоляции и безопасности дополнительно используют:

1. *RBAC* — ограничение прав пользователей и сервисов;
2. *NetworkPolicy* — ограничение сетевого трафика между Pod;
3. *ResourceQuota* — лимиты ресурсов на namespace;
4. *LimitRange* — дефолтные requests/limits для Pod.

Коротко:

```text
Namespace = логическое разделение ресурсов

Namespace ≠ firewall
Namespace ≠ отдельный кластер
Namespace ≠ полноценная security-изоляция
```

Правильнее думать так:

```text
Namespace — это основа для организации ресурсов и навешивания политик безопасности.
```