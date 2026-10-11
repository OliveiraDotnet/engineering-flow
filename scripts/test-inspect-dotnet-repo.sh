#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PACK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
INSPECTOR="$PACK_ROOT/repo-template/.agents/skills/bootstrap-dotnet-repo/scripts/inspect-dotnet-repo.sh"

modern_output="$(bash "$INSPECTOR" "$PACK_ROOT/tests/fixtures/modern-web")"
printf '%s\n' "$modern_output" | grep -q 'net8.0'
printf '%s\n' "$modern_output" | grep -q 'Suggested profiles: web$'

legacy_output="$(bash "$INSPECTOR" "$PACK_ROOT/tests/fixtures/legacy-framework")"
printf '%s\n' "$legacy_output" | grep -q 'v4.8'
printf '%s\n' "$legacy_output" | grep -q 'Suggested profiles: web'
printf '%s\n' "$legacy_output" | grep -qv 'legacy-framework'

scratch="$(mktemp -d "${TMPDIR:-/tmp}/pack-inspector.XXXXXX")"
cleanup() {
  case "$scratch" in "${TMPDIR:-/tmp}"/pack-inspector.*) rm -rf -- "$scratch" ;; *) echo 'Unsafe cleanup target' >&2; return 1 ;; esac
}
trap cleanup EXIT
for provider in EntityFramework Dapper Npgsql.EntityFrameworkCore.PostgreSQL Microsoft.EntityFrameworkCore.Sqlite Pomelo.EntityFrameworkCore.MySql; do
  printf '<Project><ItemGroup><PackageReference Include="%s" /></ItemGroup></Project>' "$provider" > "$scratch/App.csproj"
  output="$(bash "$INSPECTOR" "$scratch")"
  if printf '%s\n' "$output" | grep -q 'Suggested profiles:.*sqlserver'; then echo "False SQL Server suggestion for $provider" >&2; exit 1; fi
done
for provider in Microsoft.EntityFrameworkCore.SqlServer System.Data.SqlClient Microsoft.Data.SqlClient; do
  printf '<Project><ItemGroup><PackageReference Include="%s" /></ItemGroup></Project>' "$provider" > "$scratch/App.csproj"
  output="$(bash "$INSPECTOR" "$scratch")"
  printf '%s\n' "$output" | grep -q 'Suggested profiles:.*sqlserver'
done
printf '<Project />' > "$scratch/App.csproj"
printf '<packages><package id="System.Data.SqlClient" /></packages>' > "$scratch/packages.config"
output="$(bash "$INSPECTOR" "$scratch")"
printf '%s\n' "$output" | grep -q 'Suggested profiles:.*sqlserver'
rm -- "$scratch/packages.config"
mkdir "$scratch/obj"
printf '<Project>Microsoft.Data.SqlClient</Project>' > "$scratch/obj/Generated.csproj"
output="$(bash "$INSPECTOR" "$scratch")"
if printf '%s\n' "$output" | grep -q 'Suggested profiles:.*sqlserver'; then echo 'Generated files must be excluded' >&2; exit 1; fi
printf 'SET ANSI_NULLS ON; -- synthetic-secret-not-for-output' > "$scratch/schema.sql"
output="$(bash "$INSPECTOR" "$scratch")"
printf '%s\n' "$output" | grep -q 'Suggested profiles:.*sqlserver'
if printf '%s\n' "$output" | grep -q 'synthetic-secret'; then echo 'Inspector leaked source content' >&2; exit 1; fi
echo "Repository inspector smoke and provider tests passed."
