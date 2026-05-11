#!/usr/bin/env bash
set -euo pipefail

# Regenerates every artefact under http-annotations-evidence/ from the
# annotated .proto files on this branch. Run from the repo root.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

EVIDENCE_DIR="$REPO_ROOT/http-annotations-evidence"
PROTO_ROOT="$REPO_ROOT/community/ledger-api-proto/src/main/protobuf"
EXTERNAL_PROTOS="$REPO_ROOT/community/lib/google-common-protos-scala/target/protobuf_external"

if ! command -v buf >/dev/null 2>&1; then
  echo "buf not found in PATH; install from https://buf.build/docs/installation" >&2
  exit 1
fi

echo "== fetching google.api / google.rpc protos =="
mkdir -p "$EXTERNAL_PROTOS/google/api" "$EXTERNAL_PROTOS/google/rpc"
curl -fsSL -o "$EXTERNAL_PROTOS/google/api/annotations.proto" \
  https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/annotations.proto
curl -fsSL -o "$EXTERNAL_PROTOS/google/api/http.proto" \
  https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/http.proto
curl -fsSL -o "$EXTERNAL_PROTOS/google/rpc/status.proto" \
  https://raw.githubusercontent.com/googleapis/googleapis/master/google/rpc/status.proto

PATHS=(
  "$PROTO_ROOT/com/daml/ledger/api/v2/command_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/command_submission_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/command_completion_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/contract_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/event_query_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/package_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/state_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/update_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/version_service.proto"
  "$PROTO_ROOT/com/daml/ledger/api/v2/admin"
  "$PROTO_ROOT/com/daml/ledger/api/v2/interactive"
)
BUF_PATH_ARGS=()
for p in "${PATHS[@]}"; do BUF_PATH_ARGS+=("--path" "$p"); done

echo "== buf generate: OpenAPI 3.0.3 =="
rm -rf "$EVIDENCE_DIR/openapi-3.0/gen"
( cd "$EVIDENCE_DIR/openapi-3.0" \
  && buf generate "${BUF_PATH_ARGS[@]}" "$PROTO_ROOT" )
mv "$EVIDENCE_DIR/openapi-3.0/gen/openapi.yaml" "$EVIDENCE_DIR/openapi-3.0/openapi.yaml"
rmdir "$EVIDENCE_DIR/openapi-3.0/gen"

echo "== buf generate: Swagger 2.0 =="
rm -rf "$EVIDENCE_DIR/swagger-2.0/gen"
( cd "$EVIDENCE_DIR/swagger-2.0" \
  && buf generate "${BUF_PATH_ARGS[@]}" "$PROTO_ROOT" )
mv "$EVIDENCE_DIR/swagger-2.0/gen/canton-ledger-api.swagger.yaml" \
   "$EVIDENCE_DIR/swagger-2.0/canton-ledger-api.swagger.yaml"
rmdir "$EVIDENCE_DIR/swagger-2.0/gen"

echo "== regenerating coverage-comparison =="
JSONAPI_YAML="$REPO_ROOT/community/ledger/ledger-json-api/src/test/resources/json-api-docs/openapi.yaml"
COVERAGE_DIR="$EVIDENCE_DIR/coverage-comparison"
mkdir -p "$COVERAGE_DIR"

grep -oE '^  /v2/[^:]+' "$JSONAPI_YAML" | sort -u \
  > "$COVERAGE_DIR/paths-jsonapi.txt"

grep -oE '^    /v2/[^:]+' "$EVIDENCE_DIR/openapi-3.0/openapi.yaml" \
  | sed 's/^    //' | sort -u > "$COVERAGE_DIR/paths-proto.txt"

# Path-parameter name normalization: proto field names ↔ tapir placeholder names.
sed -E '
  s|\{identity_provider_config\.identity_provider_id\}|{idp-id}|g
  s|\{identity_provider_id\}|{idp-id}|g
  s|\{package_id\}|{package-id}|g
  s|\{user\.id\}|{user-id}|g
  s|\{user_id\}|{user-id}|g
  s|\{party_details\.party\}|{party}|g
  s|\{parties\}|{party}|g
' "$COVERAGE_DIR/paths-proto.txt" | sed 's/^/  /' | sort -u \
  > "$COVERAGE_DIR/paths-proto-normalized.txt"

comm -23 "$COVERAGE_DIR/paths-jsonapi.txt" "$COVERAGE_DIR/paths-proto-normalized.txt" \
  > "$COVERAGE_DIR/jsonapi-only.txt"
comm -13 "$COVERAGE_DIR/paths-jsonapi.txt" "$COVERAGE_DIR/paths-proto-normalized.txt" \
  > "$COVERAGE_DIR/proto-only.txt"

echo "== done =="
echo "  openapi-3.0/openapi.yaml:         $(wc -l < "$EVIDENCE_DIR/openapi-3.0/openapi.yaml") lines"
echo "  swagger-2.0/...swagger.yaml:      $(wc -l < "$EVIDENCE_DIR/swagger-2.0/canton-ledger-api.swagger.yaml") lines"
echo "  jsonapi-only paths:               $(wc -l < "$COVERAGE_DIR/jsonapi-only.txt")"
echo "  proto-only paths (after norm):    $(wc -l < "$COVERAGE_DIR/proto-only.txt")"
