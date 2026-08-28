#set page(paper: "a4", margin: (x: 2.5cm, y: 2.5cm))
#set text(size: 11pt)
#set heading(numbering: "1.")

#let capture(title) = figure(
  block(
    width: 100%,
    height: 45mm,
    stroke: 1pt + gray,
    radius: 4pt,
    inset: 10pt,
  )[
    #align(center + horizon)[
      #text(weight: 700, fill: gray)[CAPTURE À AJOUTER]
      #linebreak()
      #text(size: 9pt, fill: gray)[#title]
    ]
  ],
  caption: title,
)

#align(center)[
  #block(text(weight: 700, size: 24pt)[PROJET - AWS - Clustering ECS / Kubernetes ])
  #v(0.5em)
  #text(size: 11pt, fill: gray)[LOUHOU Godwill - LAKRIB Ikram - BENOIT Enzo]

  #text(size: 11pt, fill: gray)[#datetime.today().display()]
]

= Rappel du sujet

== Contexte
Une entreprise exploite son application conteneurisée sur deux plateformes complémentaires : Amazon ECS
(orchestrateur managé, pour la production cloud) et Kubernetes (pour la portabilité et les environnements
hors AWS). Elle nous confie l'industrialisation du déploiement sur ces deux cibles, via une seule chaîne
d'automatisation reproductible.

Il faut donc déployer la même application sur ECS et sur Kubernetes et piloter ces deux déploiements avec Terraform et Jenkins.


== Formalisation du besoin

L'objectif est de déployer la même application sur deux plateformes : Amazon ECS Fargate dans AWS
et Kubernetes avec Minikube en local.

Les deux déploiements seront créés avec Terraform et automatisés par un pipeline Jenkins.

=== Charge et disponibilité

L'application aura peu de trafic pendant la démonstration, mais elle devra pouvoir s'adapter à
une hausse de charge.

Nous utiliserons au minimum deux tâches ECS et deux pods Kubernetes. Si une tâche ou un pod
s'arrête, l'orchestrateur devra automatiquement le remplacer. Un système d'autoscaling permettra
aussi d'ajouter des instances lorsque la charge CPU augmente.

=== Sécurité

Les identifiants AWS ne seront jamais enregistrés dans Git. Ils seront ajoutés dans Jenkins sous
forme de credentials.

L'accès à ECS sera limité par un Security Group. Côté Kubernetes, le conteneur fonctionnera sans
privilèges particuliers et une règle interdira les images utilisant le tag `latest`.

=== Coût

Le projet utilise des ressources légères pour rester adapté à AWS Academy. ECS utilisera de
petites tâches Fargate et Kubernetes fonctionnera gratuitement en local avec Minikube.

Pour éviter le coût d'un Load Balancer, l'application ECS sera accessible directement avec une
adresse IP publique.

=== Contraintes

AWS sera utilisé dans la région `us-east-1`. Le rôle `LabRole` fourni par AWS Academy sera
réutilisé, car nous ne pouvons pas créer de nouveaux rôles IAM.

Kubernetes sera exécuté avec Minikube, car EKS n'est pas disponible avec les permissions du lab.

== Architecture cible

Le code de l'application et les fichiers Terraform sont stockés dans un dépôt Git. Jenkins récupère
ce dépôt, vérifie la configuration, génère un plan puis attend une approbation avant d'appliquer les
changements.

Terraform déploie ensuite l'application sur Amazon ECS Fargate et sur Kubernetes avec Minikube. Les
deux plateformes utilisent la même application Docker avec un tag précis.

#capture([Schéma général : Git, Jenkins, Terraform, ECS et Kubernetes])

= Déploiement sur ECS via Terraform
== Application utilisée

Pour tester les deux orchestrateurs, nous avons créé une petite application HTTP avec Node.js.
Elle n'utilise aucune bibliothèque externe, ce qui permet de garder l'image Docker simple et
légère.

L'application écoute sur le port `8080` et propose trois routes :

- `/` retourne le nom de l'application, sa version, la plateforme utilisée et le nom du
conteneur ;
- `/health` indique si l'application fonctionne correctement ;
- `/cpu` génère temporairement de la charge CPU pour tester l'autoscaling.

Les variables d'environnement `APP_VERSION` et `PLATFORM` permettent d'identifier la version
déployée et de vérifier si la réponse vient d'ECS ou de Kubernetes.

La route `/health` sera utilisée par les orchestrateurs pour détecter un conteneur défaillant et
le remplacer automatiquement.

== Conteneurisation de l'application

L'application est emballée dans une image Docker basée sur `node:20.18.3-alpine3.21`. Cette image
est légère et utilise une version précise de Node.js plutôt que le tag `latest`.

Le fichier `Dockerfile` réalise les opérations suivantes :

- création du dossier de travail `/app` ;
- copie du fichier `server.js` dans l'image ;
- ouverture du port `8080` ;
- exécution de l'application avec l'utilisateur non privilégié `node` ;
- lancement du serveur avec la commande `node server.js`.

Un `HEALTHCHECK` appelle régulièrement la route `/health`. Si cette route ne répond plus
correctement, le conteneur est considéré comme défaillant.

L'image a été construite localement avec le tag `orchestration-demo:v1`, puis testée avec Docker
avant son déploiement sur les orchestrateurs.

#figure(
  image("images/image-1787910076708.png"),
  caption: [Création de l'image Docker],
)

#figure(
  image("images/image-1787910166843.png"),
  caption: [Lancement du conteneur Docker sur le port local 8081],
)

#figure(
  image("images/image-1787910909131.png"),
  caption: [Vérification des routes /, /health et /cpu],
)




== Initialisation Terraform pour AWS

Terraform est utilisé pour décrire et créer l'infrastructure du projet. Les fichiers sont
regroupés dans un dossier `terraform` afin de les séparer du code de l'application.

Le provider AWS est configuré pour utiliser la région `us-east-1`, comme demandé dans le sujet.
La version de Terraform et celle du provider AWS sont également précisées pour éviter les
différences de comportement entre deux machines.

Les valeurs qui peuvent changer, comme le nom du projet, le tag de l'image ou l'adresse IP
autorisée, sont déclarées sous forme de variables.

Un fichier `terraform.tfvars` contient les valeurs utilisées sur mon poste. Ce fichier est ignoré
par Git afin d'éviter de publier une configuration personnelle. Seul un fichier
`terraform.tfvars.example` est ajouté au dépôt pour montrer la structure attendue.

La commande `terraform init` télécharge le provider AWS et prépare le dossier de travail. La
commande `terraform validate` vérifie ensuite que la configuration est correcte avant de créer
des ressources.

Création des fichiers Terraform :

`versions.tf`

```tf
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

`providers.tf`
```tf
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}
```

`variables.tf`
```tf
variable "aws_region" {
  description = "Region AWS utilisee pour le projet"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = var.aws_region == "us-east-1"
    error_message = "Le projet doit etre deploye dans us-east-1."
  }
}

variable "project_name" {
  description = "Nom utilise pour identifier les ressources"
  type        = string
  default     = "ipssi-orchestration"
}

variable "image_tag" {
  description = "Tag de l'image Docker"
  type        = string
  default     = "v1"

  validation {
    condition     = var.image_tag != "latest"
    error_message = "Le tag latest est interdit."
  }
}

variable "allowed_cidr" {
  description = "Adresse IP autorisee a contacter le service ECS"
  type        = string

  validation {
    condition     = can(cidrhost(var.allowed_cidr, 0)) && endswith(var.allowed_cidr, "/32")
    error_message = "L'adresse doit etre fournie au format x.x.x.x/32."
  }
}
```

`terraform.tfvars`

```tf
image_tag    = "v1"
allowed_cidr = "104.28.42.20/32"
```

#figure(
  image("images/image-1787912251192.png"),
  caption: [Initialisation et validation de Terraform],
)


== Création du dépôt Amazon ECR


Création des fichiers Terraform pour ECS.

#figure(
  image("images/image-1787913224196.png"),
  caption: [Arborescence du projet et du module Terraform ECS],
)


```console
➜  PROJET git:(main) ✗ terraform -chdir=terraform init
Initializing modules...
Initializing provider plugins found in the configuration...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.100.0

Initializing the backend...



Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
➜  PROJET git:(main) ✗ terraform -chdir=terraform validate
Success! The configuration is valid.

➜  PROJET git:(main) ✗ terraform -chdir=terraform plan -out=tfplan

Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # module.ecs.aws_ecr_lifecycle_policy.app will be created
  + resource "aws_ecr_lifecycle_policy" "app" {
      + id          = (known after apply)
      + policy      = jsonencode(
            {
              + rules = [
                  + {
                      + action       = {
                          + type = "expire"
                        }
                      + description  = "Conserver les dix dernieres images"
                      + rulePriority = 1
                      + selection    = {
                          + countNumber = 10
                          + countType   = "imageCountMoreThan"
                          + tagStatus   = "any"
                        }
                    },
                ]
            }
        )
      + registry_id = (known after apply)
      + repository  = "ipssi-orchestration-app"
    }

  # module.ecs.aws_ecr_repository.app will be created
  + resource "aws_ecr_repository" "app" {
      + arn                  = (known after apply)
      + force_delete         = true
      + id                   = (known after apply)
      + image_tag_mutability = "IMMUTABLE"
      + name                 = "ipssi-orchestration-app"
      + registry_id          = (known after apply)
      + repository_url       = (known after apply)
      + tags_all             = {
          + "ManagedBy" = "Terraform"
          + "Project"   = "ipssi-orchestration"
        }

      + encryption_configuration {
          + encryption_type = "AES256"
          + kms_key         = (known after apply)
        }

      + image_scanning_configuration {
          + scan_on_push = true
        }
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + ecr_repository_url = (known after apply)

─────────────────────────────────────────────────────────────────────────────────────────

Saved the plan to: tfplan

To perform exactly these actions, run the following command to apply:
    terraform apply "tfplan"
```

#figure(
  image("images/image-1787917508125.png"),
  caption: [Premier plan Terraform pour le dépôt ECR],
)

Pour continuer de mettre en place l'infrastructure, les fichiers sont mis à jour.

Un dépôt Amazon ECR est créé avec Terraform afin de stocker l'image de l'application.

Les tags du dépôt sont immuables. Une image déjà publiée ne peut donc pas être remplacée par une
autre image portant le même tag. Le scan de sécurité est activé à chaque envoi et les images sont
chiffrées par AWS.

Une politique de cycle de vie conserve uniquement les dix images les plus récentes afin de
limiter le stockage utilisé.

Pendant l'application du plan Terraform, l'image Docker est construite localement, puis envoyée
dans ECR avec un tag précis.

Le dépôt ECR est ensuite utilisé par la Task Definition du service ECS.

== Ajout du cluster ECS et du réseau

Un cluster ECS est créé pour regrouper les ressources de l'application. Container Insights est
activé afin de suivre l'utilisation des tâches. Les logs du conteneur sont envoyés dans CloudWatch
et conservés pendant sept jours.

Le projet réutilise le VPC et les sous-réseaux par défaut du compte AWS Academy. Les tâches Fargate
reçoivent une adresse IP publique afin de rendre l'application accessible sans ajouter le coût d'un
Load Balancer.

Un Security Group autorise le port `8080` uniquement depuis l'adresse IP utilisée pour la
démonstration. Les autres connexions entrantes sont refusées.

#capture([Plan Terraform ECS : dix ressources à créer])

#capture([Cluster ECS et groupe de logs CloudWatch])

#capture([Security Group limité à une adresse IP en /32])

== Task Definition Fargate

La Task Definition décrit le conteneur exécuté par ECS. Elle utilise `256` unités de CPU et `512`
Mio de mémoire, ce qui est suffisant pour l'application de démonstration.

Le rôle `LabRole` fourni par AWS Academy est utilisé comme rôle d'exécution. Il permet à ECS de
récupérer l'image dans ECR et d'envoyer les logs vers CloudWatch sans créer de nouveau rôle IAM.

Le conteneur expose le port `8080`. Une vérification appelle la route `/health` pour détecter une
application défaillante.

#capture([Task Definition : image ECR, ressources, port 8080 et rôle LabRole])

== Service ECS et autoscaling

Le service ECS maintient au moins deux tâches Fargate. Si une tâche s'arrête, le scheduler ECS en
démarre automatiquement une nouvelle. Un circuit breaker permet aussi d'annuler une version qui ne
démarre pas correctement.

L'autoscaling peut faire évoluer le service entre deux et quatre tâches. La métrique utilisée est la
consommation CPU moyenne, avec un objectif fixé à `60 %`.

#capture([Service ECS avec deux tâches en fonctionnement])

#capture([Configuration de l'autoscaling ECS entre deux et quatre tâches])

== Vérification du déploiement ECS

Après le déploiement, une adresse IP publique est récupérée depuis l'interface réseau d'une tâche.
Un appel HTTP permet de vérifier que la réponse indique la plateforme `Amazon ECS Fargate`.

#capture([Réponse HTTP obtenue depuis une tâche ECS])

Pour tester l'auto-réparation, une tâche est arrêtée manuellement. Le service doit ensuite créer une
nouvelle tâche pour revenir au nombre désiré.

#capture([Remplacement automatique d'une tâche ECS arrêtée])

= Déploiement sur Kubernetes avec Terraform

== Préparation de Minikube

La partie Kubernetes utilise le provider Terraform `kubernetes` avec le contexte `minikube`. Les
addons `ingress` et `metrics-server` sont activés pour permettre l'exposition de l'application et
la mesure de la consommation CPU.

L'image Docker construite pour ECS est également chargée dans Minikube. Les deux orchestrateurs
utilisent ainsi la même application et le même tag.

#capture([Cluster Minikube démarré et nœud dans l'état Ready])

== Deployment, ConfigMap et Service

Un namespace `orchestration-demo` isole les ressources du projet. Une ConfigMap fournit la version
de l'application et le nom de la plateforme au conteneur.

Le Deployment maintient au moins deux pods. Il définit des limites de CPU et de mémoire ainsi que
des sondes de disponibilité et de vivacité sur la route `/health`.

Un Service de type `ClusterIP` distribue le trafic entre les pods. Un Ingress NGINX expose ensuite
l'application avec le nom `demo.local`.

#capture([Deployment, pods, ConfigMap, Service et Ingress])

#capture([Réponse HTTP Kubernetes sur le port-forward local 8082])

== Autoscaling Kubernetes

Le Horizontal Pod Autoscaler maintient entre deux et six pods. Il augmente le nombre de pods lorsque
la consommation CPU moyenne dépasse `60 %`.

La route `/cpu` de l'application est utilisée pour générer une charge pendant la démonstration.

#capture([HPA avant la génération de charge])

#capture([Augmentation du nombre de pods pendant la charge])

== Sécurité Kubernetes

Le conteneur fonctionne avec un utilisateur non privilégié, sans possibilité d'augmenter ses droits
et avec toutes les capabilities Linux supprimées. Le système de fichiers racine est monté en lecture
seule et aucun jeton de ServiceAccount n'est ajouté automatiquement.

Une NetworkPolicy limite le trafic entrant vers les pods. Une ValidatingAdmissionPolicy refuse aussi
les images sans tag précis et celles qui utilisent le tag `latest`.

#capture([Refus de la création d'un pod utilisant nginx:latest])

== Auto-réparation Kubernetes

Pour tester la disponibilité, un pod de l'application est supprimé. Le Deployment doit immédiatement
créer un nouveau pod afin de conserver le nombre de réplicas demandé.

#capture([Suppression d'un pod et création automatique de son remplaçant])

= Automatisation avec Jenkins

== Configuration du pipeline

Le pipeline est stocké dans le fichier `Jenkinsfile`. Les identifiants temporaires AWS Academy sont
enregistrés dans le gestionnaire de credentials Jenkins et ne sont jamais ajoutés dans Git.

Le tag de l'image est calculé à partir du commit Git. Chaque version déployée possède ainsi un tag
différent et traçable.

Le pipeline contient les étapes suivantes :

- `Checkout` récupère le dépôt Git ;
- `Preflight` vérifie AWS, Docker et Minikube ;
- `Validate` initialise et valide Terraform ;
- `Plan` génère et archive le plan ;
- `Approve` attend une approbation humaine ;
- `Apply` applique exactement le plan approuvé ;
- `Verify` vérifie la disponibilité des deux plateformes.

#capture([Credentials AWS Academy configurés dans Jenkins, valeurs masquées])

#capture([Étapes du pipeline Jenkins])

#capture([Demande d'approbation humaine avant le déploiement])

== Idempotence

Le pipeline est relancé une seconde fois sans modifier le code. Terraform doit alors indiquer qu'il
n'existe aucun changement à appliquer. Ce test montre que le déploiement est idempotent.

#capture([Second plan Jenkins indiquant No changes])

= Difficultés rencontrées

== Conflit de ports

Jenkins utilise déjà le port local `8080`. Le premier test Docker envoyait donc les requêtes vers
Jenkins au lieu de l'application. Le conteneur Docker a finalement été exposé sur le port local
`8081`, puis le port-forward Kubernetes sur `8082`. Le port interne du conteneur reste `8080`.

== Identifiants AWS temporaires

Les identifiants AWS Academy expirent après un certain temps. Lorsque le token devient invalide, les
commandes AWS et Terraform retournent une erreur `InvalidClientTokenId`. Il faut alors relancer le lab
et mettre à jour les credentials utilisés par Jenkins.

== Contraintes AWS Academy

La création de rôles IAM et d'un cluster EKS n'est pas disponible avec les permissions du lab. Le
projet réutilise donc `LabRole` pour ECS et Minikube pour la partie Kubernetes.

= Bilan des tests

Compléter ce tableau après la démonstration :

#table(
  columns: (2fr, 1fr, 3fr),
  inset: 6pt,
  stroke: 0.5pt,
  [Test], [Résultat], [Preuve],
  [Application ECS accessible], [À compléter], [Capture de la réponse HTTP],
  [Application Kubernetes accessible], [À compléter], [Capture de la réponse HTTP],
  [Auto-réparation ECS], [À compléter], [Remplacement de la tâche],
  [Auto-réparation Kubernetes], [À compléter], [Remplacement du pod],
  [Autoscaling Kubernetes], [À compléter], [Évolution du HPA],
  [Interdiction de latest], [À compléter], [Erreur de la politique d'admission],
  [Idempotence Jenkins], [À compléter], [Second plan sans changement],
)

= Conclusion

Ce projet met en place le déploiement d'une même application sur Amazon ECS Fargate et Kubernetes.
Terraform décrit les deux environnements et Jenkins fournit une chaîne commune avec validation, plan,
approbation humaine et application des changements.

La configuration prévoit plusieurs mécanismes de disponibilité et de sécurité : plusieurs instances,
sondes de santé, autoscaling, restrictions réseau, conteneur non privilégié et images avec un tag
précis.

Les contraintes d'AWS Academy ont conduit à réutiliser `LabRole` et à utiliser Minikube à la place
d'EKS. Dans un environnement de production, cette architecture pourrait être complétée par un Load
Balancer HTTPS, un état Terraform distant et un véritable gestionnaire de secrets.

La conclusion sur le bon fonctionnement des deux déploiements sera confirmée après l'exécution du
pipeline et la réalisation de l'ensemble des tests présentés dans ce rapport.
