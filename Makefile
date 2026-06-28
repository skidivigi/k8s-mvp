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


