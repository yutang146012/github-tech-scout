#!/usr/bin/env pwsh
<#
  gh.ps1 - GitHub scout helper for the github-tech-scout skill.

  Usage:
    gh.ps1 search "<query>" [--limit N] [--stars]
    gh.ps1 readme <owner/repo> [<owner/repo> ...] [--max CHARS]

  Output is deliberately compact: one line per repo for search, and a
  size-capped README body so a caller does not burn context on banners.

  Optional: set GITHUB_TOKEN to raise the anonymous rate limits.
#>
param(
  [Parameter(Mandatory, Position = 0)][string]$Command,
  [Parameter(Position = 1, ValueFromRemainingArguments)][string[]]$Rest
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$UA = @{ 'User-Agent' = 'dsh-github-tech-scout'; 'Accept' = 'application/vnd.github+json' }
if ($env:GITHUB_TOKEN) { $UA['Authorization'] = "Bearer $($env:GITHUB_TOKEN)" }

function Get-GitHubJson([string]$Uri) {
  try {
    return Invoke-RestMethod -Uri $Uri -Headers $UA -TimeoutSec 30
  } catch {
    $resp = $_.Exception.Response
    $code = 0
    if ($resp) { $code = [int]$resp.StatusCode }
    if ($code -eq 403 -or $code -eq 429) {
      throw "GitHub rate limited (HTTP $code). Anonymous limits: search 10/min, other 60/hour. Wait 60s, or set GITHUB_TOKEN and retry."
    }
    if ($code -gt 0) { throw "Request failed (HTTP $code): $Uri" }
    throw "Network error: $($_.Exception.Message) ($Uri)"
  }
}

function ConvertTo-OneLine([string]$Text, [int]$Max) {
  if (-not $Text) { return '' }
  $t = ($Text -replace '\s+', ' ').Trim()
  if ($t.Length -gt $Max) { $t = $t.Substring(0, [Math]::Max(0, $Max - 3)) + '...' }
  return $t
}

function Invoke-Search([string[]]$Argv) {
  $limit = 6
  $sort = $null
  $words = @()
  for ($i = 0; $i -lt $Argv.Count; $i++) {
    switch ($Argv[$i]) {
      '--limit' {
        if ($i + 1 -lt $Argv.Count) { $limit = [int]$Argv[++$i] }
        else { throw '--limit needs a number' }
      }
      '--stars' { $sort = 'stars' }
      default { $words += $Argv[$i] }
    }
  }
  $q = ($words -join ' ').Trim()
  if (-not $q) { throw 'Usage: gh.ps1 search "<query>" [--limit N] [--stars]' }

  $uri = 'https://api.github.com/search/repositories?q=' + [uri]::EscapeDataString($q) + "&per_page=$limit"
  if ($sort) { $uri += "&sort=$sort&order=desc" }

  $r = Get-GitHubJson $uri
  'QUERY: ' + $q + '   matches=' + $r.total_count
  $n = 0
  foreach ($it in $r.items) {
    $n++
    $pushed = try { ([datetime]$it.pushed_at).ToString('yyyy-MM-dd') } catch { '?' }
    $lic = if ($it.license) { $it.license.spdx_id } else { 'none' }
    $arch = if ($it.archived) { ' [ARCHIVED]' } else { '' }
    $lang = if ($it.language) { $it.language } else { '?' }
    $desc = ConvertTo-OneLine $it.description 110
    '{0}. {1} | {2} star | pushed {3} | {4} | {5}{6}' -f $n, $it.full_name, $it.stargazers_count, $pushed, $lic, $lang, $arch
    '   ' + $desc
  }
  if ($n -eq 0) { '(no results - widen the query, drop qualifiers, or try topic: syntax)' }
}

function Invoke-Readme([string[]]$Argv) {
  $max = 6000
  $repos = @()
  for ($i = 0; $i -lt $Argv.Count; $i++) {
    if ($Argv[$i] -eq '--max') {
      if ($i + 1 -lt $Argv.Count) { $max = [int]$Argv[++$i] }
      else { throw '--max needs a number' }
      continue
    }
    $repos += $Argv[$i]
  }
  if ($repos.Count -eq 0) { throw 'Usage: gh.ps1 readme <owner/repo> [...] [--max CHARS]' }

  foreach ($repo in $repos) {
    $repo = $repo.Trim().TrimEnd('/')
    ''
    if ($repo -notmatch '^[\w.-]+/[\w.-]+$') { "SKIP $repo : expected owner/repo"; continue }
    "===== $repo ====="
    $got = $false
    foreach ($name in 'README.md', 'readme.md', 'README.rst', 'README', 'Readme.md') {
      $uri = "https://raw.githubusercontent.com/$repo/HEAD/$name"
      try {
        $txt = (Invoke-WebRequest -Uri $uri -Headers @{ 'User-Agent' = 'dsh-github-tech-scout' } -TimeoutSec 30 -UseBasicParsing).Content
      } catch { continue }
      if (-not $txt) { continue }

      # Drop badge walls and centered logo blocks; they are pure noise.
      $lines = $txt -split "`r?`n"
      $kept = $lines | Where-Object { $_ -notmatch '^\s*\[!\[|^\s*<p align="center"|^\s*<img\s|^\s*<div align="center"' }
      $body = ($kept -join "`n").Trim()
      if ($body.Length -gt $max) { $body = $body.Substring(0, $max) + "`n...[truncated at $max chars]" }
      $body
      $got = $true
      break
    }
    if (-not $got) { 'README fetch failed: private repo, no README on the default branch, or blocked network. Fall back to https://github.com/<owner>/<repo> or the API readme endpoint.' }
  }
}

try {
  switch ($Command.ToLowerInvariant()) {
    'search' { Invoke-Search @($Rest) }
    'readme' { Invoke-Readme @($Rest) }
    default { throw "Unknown command '$Command'. Use: search | readme" }
  }
} catch {
  # A CLI should fail with one clear line and a non-zero exit code, not a
  # PowerShell stack trace that a shell-sandboxed caller has to parse.
  [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
  exit 1
}
