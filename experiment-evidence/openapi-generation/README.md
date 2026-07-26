# Generated OpenAPI artefacts

## Contents

| File | Source |
|---|---|
| `buf.gen.yaml` | The exact `buf generate` config used to produce the OpenAPI. |
| `command_service.swagger.json` | The 1,372-line OpenAPI 2.0 document generated from the annotated `command_service.proto` (plus its transitive proto closure). This is the "after" side of the SwaggerHub comparison linked at the top of PR #1. |

## Reproduce

```bash
# from canton repo root, on this branch:

# 1. Make sure google common protos are unpacked where buf.work.yaml expects them
mkdir -p community/lib/google-common-protos-scala/target/protobuf_external/google/api \
         community/lib/google-common-protos-scala/target/protobuf_external/google/rpc
curl -sS -o community/lib/google-common-protos-scala/target/protobuf_external/google/api/annotations.proto \
  https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/annotations.proto
curl -sS -o community/lib/google-common-protos-scala/target/protobuf_external/google/api/http.proto \
  https://raw.githubusercontent.com/googleapis/googleapis/master/google/api/http.proto
curl -sS -o community/lib/google-common-protos-scala/target/protobuf_external/google/rpc/status.proto \
  https://raw.githubusercontent.com/googleapis/googleapis/master/google/rpc/status.proto

# 2. Run buf generate with the bundled config
cd experiment-evidence/openapi-generation
buf generate \
  --path ../../community/ledger-api-proto/src/main/protobuf/com/daml/ledger/api/v2/command_service.proto \
  ../../community/ledger-api-proto/src/main/protobuf

# 3. Output appears at gen/openapi/com/daml/ledger/api/v2/command_service.swagger.json
diff gen/openapi/com/daml/ledger/api/v2/command_service.swagger.json command_service.swagger.json
# (empty — byte-identical)
```

## What's in the output

Three operations, fully typed end-to-end:

```
POST /v2/commands/submit-and-wait
POST /v2/commands/submit-and-wait-for-transaction
POST /v2/commands/submit-and-wait-for-reassignment
```

Schema definitions are qualified by proto package (`com.daml.ledger.api.v2.Commands`, `com.daml.ledger.api.v2.Record`, …). No `Empty1`–`Empty10`, no single-key `oneOf` envelopes, no inline duplicated enums, no untyped DAML payload fields. See PR #1's defect-by-defect table for the side-by-side with the current tapir-emitted spec.
