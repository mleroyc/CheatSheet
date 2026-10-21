[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$DocsPath = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

# Normaliser le chemin racine
$DocsPath = (Resolve-Path -LiteralPath $DocsPath).Path

# Fichiers à déplacer : chemins relatifs au dossier docs
$moves = @(
    @{
        Source = '03-outils/post-exploitation/reverse-bind-shells.md'
        Destination = '04-methodes/web/reverse-bind-shells.md'
    },
    @{
        Source = '05-cours/red-team/web/api-testing.md'
        Destination = '01-vulnerabilites/web/server-side/api-testing.md'
    },
    @{
        Source = '05-cours/red-team/web/authentification-vulnerabilites.md'
        Destination = '01-vulnerabilites/web/auth-controle-acces/authentification-vulnerabilites.md'
    }
)

Write-Host "`n=== Réorganisation MkDocs ===" -ForegroundColor Cyan
Write-Host "Dossier docs : $DocsPath"

# Préparer et vérifier toutes les opérations avant de commencer.
$plan = @()
$errors = @()

foreach ($move in $moves) {
    $source = Join-Path $DocsPath $move.Source
    $destination = Join-Path $DocsPath $move.Destination

    $sourceExists = Test-Path -LiteralPath $source -PathType Leaf
    $destinationExists = Test-Path -LiteralPath $destination

    # Autoriser une nouvelle exécution si le déplacement est déjà fait.
    if (-not $sourceExists -and $destinationExists) {
        Write-Host "[DÉJÀ FAIT] $($move.Destination)" -ForegroundColor DarkGray
        continue
    }

    if (-not $sourceExists) {
        $errors += "Fichier source introuvable : $($move.Source)"
        continue
    }

    if ($destinationExists) {
        $errors += "Destination déjà existante : $($move.Destination)"
        continue
    }

    $plan += [PSCustomObject]@{
        Source      = $source
        Destination = $destination
        RelativeSource = $move.Source
        RelativeDestination = $move.Destination
    }
}

if ($errors.Count -gt 0) {
    Write-Host "`nAucune opération n'a été lancée." -ForegroundColor Red
    foreach ($errorMessage in $errors) {
        Write-Host " - $errorMessage" -ForegroundColor Red
    }
    throw "Vérification préalable échouée. Corrige les problèmes puis relance le script."
}

if ($plan.Count -eq 0) {
    Write-Host "`nTous les déplacements sont déjà effectués." -ForegroundColor Green
    return
}

Write-Host "`nDéplacements prévus :" -ForegroundColor Cyan
foreach ($item in $plan) {
    Write-Host " - $($item.RelativeSource)"
    Write-Host "   -> $($item.RelativeDestination)"
}

# Effectuer les déplacements après validation complète.
foreach ($item in $plan) {
    $destinationDirectory = Split-Path -Parent $item.Destination

    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        if ($PSCmdlet.ShouldProcess($destinationDirectory, 'Créer le dossier')) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force |
                Out-Null
        }
    }

    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        Write-Host "[IGNORÉ] Dossier non créé : $destinationDirectory" -ForegroundColor Yellow
        continue
    }

    if ($PSCmdlet.ShouldProcess($item.Destination, "Déplacer $($item.RelativeSource)")) {
        Move-Item -LiteralPath $item.Source -Destination $item.Destination
        Write-Host "[OK] $($item.RelativeDestination)" -ForegroundColor Green
    }
}

Write-Host "`nRéorganisation terminée." -ForegroundColor Cyan
Write-Host "Vérifie ensuite les liens internes Markdown et lance : mkdocs build"