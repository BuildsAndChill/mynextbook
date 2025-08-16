# Configuration Google Custom Search API

## Étape 1: Créer un projet Google Cloud

1. Allez sur [Google Cloud Console](https://console.cloud.google.com/)
2. Créez un nouveau projet ou sélectionnez un projet existant
3. Activez l'API "Custom Search API" pour votre projet

## Étape 2: Créer des identifiants API

1. Dans le menu, allez à "APIs & Services" > "Credentials"
2. Cliquez sur "Create Credentials" > "API Key"
3. Copiez votre clé API (vous en aurez besoin pour `GOOGLE_CUSTOM_SEARCH_API_KEY`)

## Étape 3: Créer un moteur de recherche personnalisé

1. Allez sur [Google Programmable Search Engine](https://programmablesearchengine.google.com/)
2. Cliquez sur "Create a search engine"
3. Configurez votre moteur de recherche :
   - **Sites to search**: Laissez vide pour rechercher sur tout le web
   - **Name**: Donnez un nom à votre moteur de recherche
   - **Language**: Sélectionnez la langue souhaitée
4. Cliquez sur "Create"
5. Copiez votre Search Engine ID (vous en aurez besoin pour `GOOGLE_CUSTOM_SEARCH_ENGINE_ID`)

## Étape 4: Configurer les variables d'environnement

Ajoutez ces variables à votre fichier `.env` :

```bash
GOOGLE_CUSTOM_SEARCH_API_KEY=votre_clé_api_ici
GOOGLE_CUSTOM_SEARCH_ENGINE_ID=votre_search_engine_id_ici
```

## Étape 5: Tester l'API

L'API est maintenant configurée ! Quand un utilisateur clique sur "Voir plus sur Goodreads", l'application :

1. Effectue une recherche Google Custom Search pour le livre
2. Récupère le premier résultat (lien direct vers Goodreads, Amazon, etc.)
3. Redirige l'utilisateur vers ce lien direct

## Avantages de cette approche

- ✅ **Fiable** : Pas de parsing HTML instable
- ✅ **Rapide** : API officielle Google
- ✅ **Précis** : Résultats de recherche de qualité
- ✅ **Sécurisé** : Pas de risque de blocage IP
- ✅ **Limites claires** : 100 requêtes gratuites par jour

## Coûts

- **Gratuit** : 100 requêtes par jour
- **Payant** : $5 pour 1000 requêtes supplémentaires

## Dépannage

Si vous obtenez des erreurs :
1. Vérifiez que l'API Custom Search est activée
2. Vérifiez que votre clé API est correcte
3. Vérifiez que votre Search Engine ID est correct
4. Vérifiez les logs Rails pour plus de détails

