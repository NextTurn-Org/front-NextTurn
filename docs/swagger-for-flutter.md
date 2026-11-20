# Utiliser Swagger (OpenAPI) pour connecter le front Flutter au back Symfony

Swagger (OpenAPI) est bien adapté ici. Par contre, on n'appelle pas Swagger directement depuis Flutter. Le back décrit ses controllers dans un fichier OpenAPI (`openapi.json`), et un générateur transforme ce fichier en client Dart typé. Le front appelle ensuite des méthodes comme `categoryApi.listCategories()` sans jamais écrire d'URL ni de parsing JSON à la main.

`back-NextTurn` est en Symfony 7.4 avec des entités Doctrine (Category, Game, Event, …) et pas encore de controllers. Voici à quoi ressemblerait le flux complet avec `Category`.

```
back-NextTurn (controllers Symfony + attributs PHP)
        │  NelmioApiDocBundle
        ▼
   /api/doc.json  (spec OpenAPI)   +  Swagger UI sur /api/doc
        │  openapi-generator (dart-dio)
        ▼
front-NextTurn/app/packages/nextturn_api  (client Dart généré)
        │
        ▼
   Les widgets Flutter appellent CategoryApi.listCategories()
```

---

### 1. Back : publier la spec OpenAPI

```bash
composer require nelmio/api-doc-bundle symfony/twig-bundle symfony/asset symfony/serializer-pack
```

`config/routes/nelmio_api_doc.yaml` :

```yaml
app.swagger_ui:
  path: /api/doc
  methods: GET
  defaults: { _controller: nelmio_api_doc.controller.swagger_ui }

app.swagger_json:
  path: /api/doc.json
  methods: GET
  defaults: { _controller: nelmio_api_doc.controller.swagger }
```

`config/packages/nelmio_api_doc.yaml` :

```yaml
nelmio_api_doc:
  documentation:
    info:
      title: NextTurn API
      version: 1.0.0
  areas:
    path_patterns: [ ^/api(?!/doc) ]
```

Un DTO sépare le contrat de l'API de l'entité Doctrine : ça évite d'exposer les relations ou de boucler sur `games`. À mettre dans `src/Dto/CategoryDto.php` :

```php
<?php
namespace App\Dto;

use OpenApi\Attributes as OA;
use Symfony\Component\Validator\Constraints as Assert;

final class CategoryDto
{
    public function __construct(
        #[OA\Property(format: 'uuid', readOnly: true)]
        public readonly ?string $id = null,

        #[Assert\NotBlank, Assert\Length(max: 255)]
        public readonly string $name = '',
    ) {}
}
```

`src/Controller/CategoryController.php` :

```php
<?php
namespace App\Controller;

use App\Dto\CategoryDto;
use App\Entity\Category;
use App\Repository\CategoryRepository;
use Doctrine\ORM\EntityManagerInterface;
use Nelmio\ApiDocBundle\Attribute\Model;
use OpenApi\Attributes as OA;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpKernel\Attribute\MapRequestPayload;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/api/categories')]
#[OA\Tag(name: 'Category')]
final class CategoryController extends AbstractController
{
    #[Route('', name: 'listCategories', methods: ['GET'])]
    #[OA\Response(response: 200, description: 'All categories',
        content: new OA\JsonContent(type: 'array', items: new OA\Items(ref: new Model(type: CategoryDto::class))))]
    public function list(CategoryRepository $repo): JsonResponse
    {
        return $this->json(array_map(
            fn (Category $c) => new CategoryDto((string) $c->getId(), $c->getName()),
            $repo->findAll(),
        ));
    }

    #[Route('', name: 'createCategory', methods: ['POST'])]
    #[OA\RequestBody(content: new OA\JsonContent(ref: new Model(type: CategoryDto::class)))]
    #[OA\Response(response: 201, description: 'Created', content: new Model(type: CategoryDto::class))]
    public function create(#[MapRequestPayload] CategoryDto $dto, EntityManagerInterface $em): JsonResponse
    {
        $category = (new Category())->setName($dto->name);
        $em->persist($category);
        $em->flush();

        return $this->json(new CategoryDto((string) $category->getId(), $category->getName()), 201);
    }
}
```

Ouvre `http://localhost:8000/api/doc` pour tester les endpoints dans Swagger UI. `/api/doc.json` est le fichier qu'utilise le front.

Il faudra aussi gérer le CORS (`nelmio/cors-bundle`) si tu lances Flutter web contre le back.

---

### 2. Front : générer le client Dart

Génération ponctuelle (nécessite Java, sinon utiliser l'image Docker). À lancer depuis `front-NextTurn/app` :

```bash
npx @openapitools/openapi-generator-cli generate -i http://localhost:8000/api/doc.json -g dart-dio -o packages/nextturn_api --additional-properties=pubName=nextturn_api
```

```bash
cd packages/nextturn_api && dart run build_runner build --delete-conflicting-outputs
```

Puis dans `app/pubspec.yaml` :

```yaml
dependencies:
  nextturn_api:
    path: packages/nextturn_api
```

Relance le générateur à chaque modification d'un controller. C'est tout l'intérêt : si le back renomme un champ, le code Flutter ne compile plus, au lieu de planter à l'exécution.

---

### 3. Front : l'utiliser dans Flutter

`lib/api.dart` :

```dart
import 'package:nextturn_api/nextturn_api.dart';

// Émulateur Android : 10.0.2.2 pointe vers le localhost de ta machine
const _baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

final api = NextturnApi(basePathOverride: _baseUrl);
final categoryApi = api.getCategoryApi();
```

`lib/categories_page.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:nextturn_api/nextturn_api.dart';
import 'api.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  late Future<List<CategoryDto>> _future = _load();

  Future<List<CategoryDto>> _load() async {
    final res = await categoryApi.listCategories();
    return res.data?.toList() ?? [];
  }

  Future<void> _add(String name) async {
    await categoryApi.createCategory(
      categoryDto: CategoryDto((b) => b..name = name),
    );
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _add('Board games'),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => ListTile(title: Text(items[i].name)),
          );
        },
      ),
    );
  }
}
```

Les noms des méthodes viennent du `name` des routes Symfony (`listCategories`, `createCategory`), donc donne des noms propres à tes routes. `CategoryDto` est généré à partir du DTO PHP.

---

### Remarques

- **Choix du générateur :** `dart-dio` (d'openapi-generator) est le plus utilisé. Une alternative est `swagger_dart_code_generator` avec Chopper, qui tourne dans le `build_runner` de Flutter : pas besoin de Java ni de npx.
- **Authentification plus tard :** si tu ajoutes du JWT (par exemple LexikJWT), déclare un `securitySchemes` bearer dans la config Nelmio. Le client généré aura alors un helper `setBearerAuth(...)`.
- **Ne modifie pas le dossier généré à la main :** considère `packages/nextturn_api` comme une sortie de build. Soit tu le commits, soit tu le régénères dans la CI.
