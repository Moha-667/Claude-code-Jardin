# Synchronise le dashboard depuis GitHub vers Node-RED (Windows PowerShell).
#
# Usage :
#   .\sync_dashboard.ps1            # une synchronisation puis quitte
#   .\sync_dashboard.ps1 -Watch     # vérifie GitHub toutes les 60 s et déploie
#
# Si l'éditeur Node-RED est protégé par mot de passe (adminAuth) :
#   .\sync_dashboard.ps1 -Watch -User admin -Password monmotdepasse

param(
    [switch] $Watch,
    [string] $Branch = "claude/dashboard-ocean-impl-lxclfd",
    [string] $FlowFile = "flows_84_corrige.json",
    [string] $NodeRedUrl = "http://127.0.0.1:1880",
    [string] $User = "",
    [string] $Password = "",
    [int] $IntervalSec = 60
)

$ErrorActionPreference = "Stop"
$repoDir = $PSScriptRoot

function Get-Token {
    if (-not $User) { return $null }
    $body = @{ client_id = "node-red-admin"; grant_type = "password"; scope = "*";
               username = $User; password = $Password }
    (Invoke-RestMethod -Method Post -Uri "$NodeRedUrl/auth/token" -Body $body).access_token
}

function Deploy-Flows {
    $flows = Get-Content -Raw -Encoding UTF8 (Join-Path $repoDir $FlowFile)
    $headers = @{ "Node-RED-Deployment-Type" = "full" }
    $token = Get-Token
    if ($token) { $headers["Authorization"] = "Bearer $token" }
    Invoke-RestMethod -Method Post -Uri "$NodeRedUrl/flows" -Headers $headers `
        -ContentType "application/json; charset=utf-8" -Body $flows | Out-Null
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✅ Déployé dans Node-RED"
}

function Sync-Once {
    Set-Location $repoDir
    git fetch origin $Branch 2>&1 | Out-Null
    $local = git rev-parse HEAD
    $remote = git rev-parse "origin/$Branch"
    if ($local -ne $remote) {
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ⬇ Nouvelle version : $($remote.Substring(0,7))"
        git checkout $Branch 2>&1 | Out-Null
        git reset --hard "origin/$Branch" | Out-Null
        Deploy-Flows
        return $true
    }
    return $false
}

if ($Watch) {
    Write-Host "Surveillance de origin/$Branch toutes les $IntervalSec s — Ctrl+C pour arrêter."
    # premier passage : déploie l'état courant même sans nouveauté
    try { Sync-Once | Out-Null; Deploy-Flows } catch { Write-Warning $_ }
    while ($true) {
        Start-Sleep -Seconds $IntervalSec
        try { Sync-Once | Out-Null } catch { Write-Warning $_ }
    }
} else {
    if (-not (Sync-Once)) {
        Write-Host "Déjà à jour — redéploiement de l'état courant."
        Deploy-Flows
    }
}
