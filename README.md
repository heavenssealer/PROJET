# Projet ECS et Kubernetes

Ce projet deploie la meme application sur Amazon ECS Fargate et sur Kubernetes avec Minikube. L'infrastructure est decrite avec Terraform et appliquee par un pipeline Jenkins commun.

## Structure

```text
app/                 application Node.js et Dockerfile
terraform/           configuration Terraform principale
terraform/modules/   modules ECS et Kubernetes
docs/architecture.mmd
Jenkinsfile
```

## Prerequis

- Terraform 1.6 ou plus recent
- Docker
- AWS CLI v2
- Minikube et kubectl
- Jenkins avec les plugins Pipeline, Git, Credentials Binding et AnsiColor

Demarrer le cluster local :

```bash
minikube start -p minikube --cpus=4 --memory=4096
```

Copier la configuration d'exemple et renseigner son adresse IP publique :

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Verifier Terraform sans creer de ressource :

```bash
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=tfplan
```

## Jenkins

Creer trois credentials Jenkins de type `Secret text` :

- `aws-academy-access-key-id`
- `aws-academy-secret-access-key`
- `aws-academy-session-token`

Creer ensuite un job `Pipeline from SCM` et fournir le parametre `ALLOWED_CIDR` au format `x.x.x.x/32`. Le pipeline execute la validation, le plan, une approbation humaine, l'apply et les verifications.

## Verification locale

Kubernetes utilise le port-forward `8082` pour ne pas entrer en conflit avec Jenkins (`8080`) ni le test Docker (`8081`) :

```bash
kubectl -n orchestration-demo get deployment,pods,service,ingress,hpa
kubectl -n orchestration-demo port-forward service/orchestration-demo 8082:80
curl http://127.0.0.1:8082/
```

Pour tester l'autoscaling Kubernetes :

```bash
kubectl -n orchestration-demo create deployment load-generator --image=busybox:1.36.1 -- /bin/sh -c 'while true; do wget -q -O- http://orchestration-demo/cpu >/dev/null; done'
kubectl -n orchestration-demo scale deployment/load-generator --replicas=10
kubectl -n orchestration-demo get hpa,pods -w
```

Supprimer ensuite la charge :

```bash
kubectl -n orchestration-demo delete deployment load-generator
```
