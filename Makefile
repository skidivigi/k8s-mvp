CLUSTER_NAME=platform-lab

# 1st lab
.PHONY: create
create:
	kind create cluster --config kind/cluster.yaml

.PHONY: delete
delete:
	kind delete cluster --name $(CLUSTER_NAME)

.PHONY: nodes
nodes:
	kubectl get nodes -o wide

.PHONY: pods
pods:
	kubectl get pods -A

.PHONY: ns
ns:
	kubectl get namespaces

.PHONY: apply-ns
apply-ns:
	kubectl apply -f k8s/00-namespaces/namespaces.yaml

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

.PHONY: delete-one-pod-3
delete-one-pod-3:
	kubectl delete pod -n lab -l app=hello

.PHONY: scale-deploy-3
scale-deploy-3:
	kubectl scale deploy hello-deployment --replicas=5 -n lab

.PHONY: scale-deploy-back-3
scale-deploy-back-3:
	kubectl scale deploy hello-deployment --replicas=3 -n lab

.PHONY: delete-deploy-3
delete-deploy-3:
	kubectl delete -f k8s/02-deployment/deployment.yaml

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

# 6th lab - Ingress

.PHONY: setup-ingress-6
setup-ingress-6:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl label node platform-lab-control-plane ingress-ready=true --overwrite
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='merge' -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux","ingress-ready":"true"}}}}}'
	kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx
	kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=180s
	kubectl get pods -n ingress-nginx -o wide

.PHONY: install-ingress-controller-6
install-ingress-controller-6:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

.PHONY: fix-ingress-node-6
fix-ingress-node-6:
	kubectl patch deployment ingress-nginx-controller -n ingress-nginx --type='merge' -p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/os":"linux","ingress-ready":"true"}}}}}'
	kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

.PHONY: wait-ingress-controller-6
wait-ingress-controller-6:
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=180s

.PHONY: get-ingress-controller-6
get-ingress-controller-6:
	kubectl get pods -n ingress-nginx -o wide

.PHONY: delete-ingress-controller-6
delete-ingress-controller-6:
	kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

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

# 10th lab - Metrics Server

.PHONY: install-metrics-server-10
install-metrics-server-10:
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

.PHONY: patch-metrics-server-10
patch-metrics-server-10:
	kubectl patch deployment metrics-server -n kube-system --type='strategic' --patch-file k8s/09-metrics-server/patch.yaml

.PHONY: rollout-metrics-server-10
rollout-metrics-server-10:
	kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

.PHONY: setup-metrics-server-10
setup-metrics-server-10:
	kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
	kubectl patch deployment metrics-server -n kube-system --type='strategic' --patch-file k8s/09-metrics-server/patch.yaml
	kubectl rollout status deployment/metrics-server -n kube-system --timeout=180s

.PHONY: get-metrics-server-10
get-metrics-server-10:
	kubectl get pods -n kube-system -l k8s-app=metrics-server -o wide

.PHONY: describe-metrics-server-10
describe-metrics-server-10:
	kubectl describe deployment metrics-server -n kube-system

.PHONY: logs-metrics-server-10
logs-metrics-server-10:
	kubectl logs -n kube-system -l k8s-app=metrics-server

.PHONY: top-pods-10
top-pods-10:
	kubectl top pods -n lab

.PHONY: top-pods-all-10
top-pods-all-10:
	kubectl top pods -A

.PHONY: top-nodes-10
top-nodes-10:
	kubectl top nodes

.PHONY: raw-node-metrics-10
raw-node-metrics-10:
	kubectl get --raw "/apis/metrics.k8s.io/v1beta1/nodes" | jq .

.PHONY: raw-pod-metrics-10
raw-pod-metrics-10:
	kubectl get --raw "/apis/metrics.k8s.io/v1beta1/pods" | jq .

.PHONY: delete-metrics-server-10
delete-metrics-server-10:
	kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

