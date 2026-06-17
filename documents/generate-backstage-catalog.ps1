```powershell
# generate-backstage-catalog.ps1

$root = "backstage-catalog-new"

# Create folders
@(
    "$root/apis",
    "$root/components",
    "$root/groups",
    "$root/resources",
    "$root/systems",
    "$root/users",
    "$root/templates"
) | ForEach-Object {
    New-Item -ItemType Directory -Force -Path $_ | Out-Null
}

$repos = Get-Content "repos.json" | ConvertFrom-Json
$targets = @()

foreach ($repo in $repos) {

    $repoName = ($repo.name.ToLower() -replace '[^a-z0-9-]', '-')
    $owner = $repo.owner.login
    $repoUrl = $repo.url
    $description = $repo.description

    if ([string]::IsNullOrWhiteSpace($description)) {
        $description = "$repoName repository"
    }

    # Detect component type
    $type = "service"
    if ($repoName -match "frontend|ui|angular|web") {
        $type = "website"
    }

    # Build tags
    $tags = @()

    if ($repo.languages) {
        foreach ($lang in $repo.languages) {
            if ($lang.name) {
                $tag = ($lang.name.ToLower() -replace '[^a-z0-9-]', '-')
                $tags += $tag
            }
        }
    }

    $tags += "backstage"

    if ($type -eq "service") {
        $tags += "microservice"
    }

    $tags = $tags | Select-Object -Unique

    # Build tags YAML
    $tagsYaml = ""
    if ($tags.Count -gt 0) {
        $tagsYaml += "`n  tags:"
        foreach ($tag in $tags) {
            $tagsYaml += "`n    - $tag"
        }
    }

    # Component YAML
    $componentYaml = @"
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: $repoName
  description: "$description"$tagsYaml
  annotations:
    github.com/project-slug: $owner/$($repo.name)
    backstage.io/source-location: url:$repoUrl
    backstage.io/view-url: $repoUrl
spec:
  type: $type
  lifecycle: production
  owner: team

  dependsOn:
    - resource:default/mongodb

  providesApis:
    - $repoName-api
"@

    $componentYaml | Out-File -Encoding utf8 "$root/components/$repoName.yaml"

    # API YAML
    $apiYaml = @"
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: $repoName-api
  description: API for $repoName
spec:
  type: openapi
  lifecycle: production
  owner: team
  definition: |
    openapi: 3.0.0
    info:
      title: $repoName API
      version: 1.0.0
    paths: {}
"@

    $apiYaml | Out-File -Encoding utf8 "$root/apis/$repoName-api.yaml"

    $targets += "./components/$repoName.yaml"
    $targets += "./apis/$repoName-api.yaml"
}

# MongoDB Resource
$mongoYaml = @"
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: mongodb
  description: Shared MongoDB Database
spec:
  type: database
  owner: team
"@

$mongoYaml | Out-File -Encoding utf8 "$root/resources/mongodb.yaml"
$targets += "./resources/mongodb.yaml"

# Team Group
$groupYaml = @"
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: team
spec:
  type: team
  profile:
    displayName: Platform Team
  children: []
"@

$groupYaml | Out-File -Encoding utf8 "$root/groups/team.yaml"
$targets += "./groups/team.yaml"

# Root catalog-info.yaml
$catalog = @"
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: root-catalog
spec:
  targets:
"@

foreach ($target in $targets) {
    $catalog += "`n    - $target"
}

$catalog | Out-File -Encoding utf8 "$root/catalog-info.yaml"

Write-Host "Backstage catalog generated successfully!"
```
