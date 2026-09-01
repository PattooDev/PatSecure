# Rapports PatSecure et confidentialité

PatSecure v0.4.0 produit deux rapports différents afin de séparer le diagnostic local des informations pouvant être partagées.

## Rapport privé

Emplacement :

```text
~/.local/state/patsecure/reports/private/
```

Ce rapport peut contenir des informations techniques détaillées utiles au diagnostic, par exemple les sorties de `ss`, UFW ou nftables.

Il est créé avec les permissions `600`, ce qui signifie qu'il est lisible et modifiable uniquement par son propriétaire dans les conditions normales d'utilisation.

### Recommandation

Ne pas publier le rapport privé sur GitHub, un forum, un site Web ou un réseau social sans l'avoir relu et anonymisé.

## Rapport partageable

Emplacement :

```text
~/.local/state/patsecure/reports/shareable/
```

Ce rapport est construit séparément. Il ne s'agit pas d'une simple copie du rapport privé après suppression de quelques lignes.

Il ne reçoit pas :

- les sorties brutes des commandes réseau ;
- les adresses IP locales ;
- les adresses MAC ;
- le nom de la machine ;
- le nom de l'utilisateur.

PatSecure ne contacte aucun service externe pour connaître l'adresse IP publique.

## UPnP

Si la commande `upnpc` est installée, PatSecure peut interroger en lecture seule la passerelle locale pour déterminer si UPnP/IGD répond.

L'adresse IP externe éventuellement renvoyée par la passerelle :

- n'est pas affichée par PatSecure ;
- n'est pas copiée dans le rapport privé ;
- n'est pas copiée dans le rapport partageable.

Seul le résultat synthétique de la détection est conservé.

## Interprétation des ports

Une écoute sur `0.0.0.0`, `::` ou plusieurs interfaces signifie qu'un service accepte potentiellement des connexions au-delà de la seule boucle locale.

Cela **ne prouve pas** que ce service est accessible depuis Internet.

L'exposition réelle dépend notamment :

- du pare-feu local ;
- du routeur et des redirections de ports ;
- de la présence ou non de CGNAT ;
- de la configuration IPv6 ;
- des règles de filtrage du réseau ;
- du service lui-même.

## Avant de partager un rapport

Le rapport `shareable` est celui prévu pour être communiqué. Une lecture rapide avant publication reste recommandée, notamment après toute modification future du script.
