# Projet ECS et Kubernetes

Ce dépôt déploie la même application Node.js sur Amazon ECS Fargate et sur un cluster Kubernetes
Minikube. Terraform décrit les deux cibles. Jenkins lance la validation, produit le plan, attend une
confirmation humaine, puis applique ce plan.

## Contenu du dépôt

```text
app/                    application Node.js et Dockerfile
docs/architecture.mmd   schéma de l'architecture
terraform/              configuration Terraform principale
terraform/modules/ecs/  ressources ECR et ECS Fargate
terraform/modules/k8s/  ressources Kubernetes
Jenkinsfile             pipeline commun aux deux cibles
rapport.typ              rapport du projet
```

## Prérequis

Le poste qui exécute Jenkins doit avoir accès aux commandes suivantes :

- Terraform 1.6 ou plus récent ;
- Docker ;
- AWS CLI v2 ;
- Minikube ;
- kubectl ;
- Git.

Jenkins utilise les plugins Pipeline, Git et Credentials Binding. Docker Desktop doit être démarré
avant le pipeline.

## Préparer Minikube

Le pipeline vérifie l'état de Minikube, mais il ne crée pas le cluster. Il faut le démarrer une fois
sur la machine Jenkins :

```bash
minikube start -p minikube --cpus=4 --memory=4096
```

Terraform active ensuite les addons `ingress` et `metrics-server`.

## Configurer les accès AWS Academy

Les identifiants AWS Academy sont temporaires. Dans Jenkins, créer trois credentials de type
`Secret text` avec ces identifiants exacts :

- `aws-academy-access-key-id` ;
- `aws-academy-secret-access-key` ;
- `aws-academy-session-token`.

Leurs valeurs ne doivent jamais être ajoutées au dépôt. Quand le lab expire, il faut le relancer et
remplacer les trois valeurs dans Jenkins.

Pour vérifier la session depuis un terminal :

```bash
aws sts get-caller-identity
```

## Créer le job Jenkins

Créer un job de type `Pipeline`, puis choisir `Pipeline script from SCM` avec les valeurs suivantes :

```text
SCM               Git
Repository URL    https://github.com/heavenssealer/PROJET.git
Branch            */main
Script Path       Jenkinsfile
```

Lancer ensuite `Build with Parameters`. Le paramètre `ALLOWED_CIDR` attend l'adresse IPv4 publique
du poste Jenkins au format `/32`.

```bash
printf '%s/32\n' "$(curl -4 -s https://api.ipify.org)"
```

Le pipeline exécute les étapes suivantes :

1. `Checkout` récupère le commit Git et utilise son hash court comme tag d'image.
2. `Preflight` vérifie Docker, AWS et Minikube.
3. `Validate` initialise Terraform, contrôle le format et valide les fichiers.
4. `Plan` crée puis archive `tfplan.txt`.
5. `Approve` attend une confirmation humaine pendant vingt minutes.
6. `Apply` applique le plan validé.
7. `Verify` attend la disponibilité des pods et des tâches ECS.

## Lancer Terraform sans Jenkins

Cette méthode sert au diagnostic. Le déploiement présenté dans le projet passe par Jenkins.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform validate
terraform -chdir=terraform plan -out=tfplan
```

Il faut remplacer l'adresse d'exemple dans `terraform/terraform.tfvars` par l'adresse IPv4 publique
du poste.

## Vérifier ECS

Contrôler l'état du service :

```bash
aws ecs describe-services \
  --cluster ipssi-orchestration-cluster \
  --services ipssi-orchestration-service \
  --query 'services[0].{Desirees:desiredCount,Actives:runningCount,EnAttente:pendingCount,Statut:status}' \
  --output table \
  --no-cli-pager
```

Retrouver l'adresse publique d'une tâche puis appeler l'application :

```bash
TASK_ARN="$(aws ecs list-tasks \
  --cluster ipssi-orchestration-cluster \
  --service-name ipssi-orchestration-service \
  --query 'taskArns[0]' \
  --output text)"

ENI_ID="$(aws ecs describe-tasks \
  --cluster ipssi-orchestration-cluster \
  --tasks "$TASK_ARN" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value | [0]' \
  --output text)"

ECS_IP="$(aws ec2 describe-network-interfaces \
  --network-interface-ids "$ENI_ID" \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text)"

curl "http://${ECS_IP}:8080/"
curl "http://${ECS_IP}:8080/health"
```

Pour tester l'autoréparation, arrêter une tâche puis attendre la stabilisation du service :

```bash
aws ecs stop-task \
  --cluster ipssi-orchestration-cluster \
  --task "$TASK_ARN" \
  --reason "Test auto-reparation"

aws ecs wait services-stable \
  --cluster ipssi-orchestration-cluster \
  --services ipssi-orchestration-service
```

## Vérifier Kubernetes

Afficher les ressources créées par Terraform :

```bash
kubectl --context minikube \
  -n orchestration-demo \
  get deployment,pods,configmap,service,ingress,hpa
```

Le port-forward utilise `8082`. Jenkins occupe déjà `8080` et le test Docker local utilise `8081`.

```bash
kubectl --context minikube \
  -n orchestration-demo \
  port-forward service/orchestration-demo 8082:80
```

Dans un autre terminal :

```bash
curl http://127.0.0.1:8082/
curl http://127.0.0.1:8082/health
```

## Tester le HPA

Les pods de charge appellent `/cpu` en boucle :

```bash
kubectl --context minikube \
  -n orchestration-demo \
  create deployment load-generator \
  --image=busybox:1.36.1 \
  -- /bin/sh -c 'while true; do wget -q -O- http://orchestration-demo/cpu >/dev/null; done'

kubectl --context minikube \
  -n orchestration-demo \
  scale deployment/load-generator --replicas=10

kubectl --context minikube \
  -n orchestration-demo \
  get hpa,pods -w
```

Une fois le nombre de pods augmenté, supprimer la charge :

```bash
kubectl --context minikube \
  -n orchestration-demo \
  delete deployment load-generator
```

## Tester les garde-fous Kubernetes

La politique d'admission doit refuser cette commande à cause du tag `latest` :

```bash
kubectl --context minikube \
  -n orchestration-demo \
  run forbidden-latest \
  --image=nginx:latest
```

Pour vérifier l'autoréparation, supprimer un pod de l'application :

```bash
POD_NAME="$(kubectl --context minikube \
  -n orchestration-demo \
  get pods -l app=orchestration-demo \
  -o jsonpath='{.items[0].metadata.name}')"

kubectl --context minikube \
  -n orchestration-demo \
  delete pod "$POD_NAME"

kubectl --context minikube \
  -n orchestration-demo \
  get pods -l app=orchestration-demo -w
```

## Vérifier l'idempotence

Relancer le même build Jenkins sans modifier le commit ni les paramètres. L'étape `Plan` doit
afficher :

```text
No changes. Your infrastructure matches the configuration.
```

## Nettoyer les ressources

La destruction demande une session AWS Academy encore active :

```bash
terraform -chdir=terraform destroy
```

Arrêter ensuite le cluster local si personne ne l'utilise :

```bash
minikube stop -p minikube
```
