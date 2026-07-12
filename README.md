# Kubernetes Platform Lab

Учебная лаборатория для пошагового изучения Kubernetes и связанных инструментов на базе `kind`.

Репозиторий нужен, чтобы пройти путь от базовых объектов Kubernetes до production-like подхода: Helm, Argo CD, Ingress, storage, observability и базовая безопасность.

## Что изучаем

В рамках лаборатории постепенно разберем:

* `kind`;
* `kubectl`;
* Kubernetes cluster;
* Node;
* Namespace;
* Pod;
* Deployment;
* ReplicaSet;
* Service;
* Ingress;
* ConfigMap;
* Secret;
* PV / PVC;
* probes;
* requests / limits;
* RBAC;
* NetworkPolicy;
* Helm;
* Argo CD;
* observability;
* security basics.

## Идея проекта

Мы не просто читаем про Kubernetes, а постепенно собираем локальную платформу:

```text
kind cluster
  ├── namespaces
  ├── demo app
  ├── pod
  ├── deployment
  ├── service
  ├── ingress
  ├── configmap / secret
  ├── volumes
  ├── statefulset
  ├── probes
  ├── requests / limits
  ├── rbac
  ├── network policy
  ├── helm
  ├── argocd
  ├── metrics-server
  └── observability
```

Каждый шаг лежит в отдельном файле в папке `docs/`.

## Структура проекта

```text
kubernetes-platform-lab/
├── README.md
├── Makefile
├── kind/
│   └── cluster.yaml
├── apps/
│   └── hello-api/
├── k8s/
│   ├── 00-namespaces/
│   ├── 01-pod/
│   ├── 02-deployment/
│   ├── 03-service/
│   ├── 04-configmap-secret/
│   ├── 05-ingress/
│   ├── 06-storage/
│   ├── 07-statefulset/
│   ├── 08-probes-resources/
│   ├── 09-metrics-server/
│   ├── 10-rbac/
│   └── 11-network-policy/
├── helm/
├── argocd/
└── docs/
```

## Требования

Для работы нужны:

* Docker;
* kind;
* kubectl;
* make;
* Git.

Проверка:

```bash
docker version
kind version
kubectl version --client
make --version
git --version
```

## Быстрый старт

Создать kind-кластер:

```bash
make create
```

Проверить ноды:

```bash
make nodes
```

Создать namespace:

```bash
make apply-ns
```

Проверить namespace:

```bash
make ns
```

Посмотреть все Pod в кластере:

```bash
make pods
```

Удалить кластер:

```bash
make delete
```

## Документация

### База

1. [Первый запуск kind-кластера](docs/1st.md)
2. [Первый Pod](docs/2nd.md)
3. [Deployment и ReplicaSet](docs/3rd.md)
4. [Service и доступ к приложению](docs/4th.md)
5. [ConfigMap и Secret](docs/5th.md)
6. [Ingress](docs/6th.md)
7. [Volumes, PV и PVC](docs/7th.md)
8. [Stateful Set](docs/8th.md)
9. [Probes, requests и limits](docs/9th.md)
10. [Metrics Server и kubectl top](docs/10th.md)
11. [RBAC](docs/11th.md)
12. [NetworkPolicy](docs/12th.md)

### Дальше

13. [Helm](docs/13th.md)
14. [Argo CD и GitOps](docs/14th.md)
15. [cert-manager и TLS](docs/15th.md)
16. [Observability](docs/16th.md)
17. [Security basics](docs/17th.md)

## Главная мысль

Kubernetes работает по декларативной модели.

Мы описываем желаемое состояние в YAML-файлах, например:

```bash
kubectl apply -f deployment.yaml
```

А Kubernetes сам приводит кластер к этому состоянию:

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

На каждом шаге будем разбирать не только команды, но и то, что происходит внутри Kubernetes.
