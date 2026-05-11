# HTTP annotations evidence

Burden-of-evidence artefacts for the PR that adds `google.api.http`
annotations across **every** HTTP-exposed RPC of the JSON Ledger API
(extending the single-service `command_service.proto` experiment to
full coverage).

**Internal to the Peaceful Studio fork.** Delete this directory before
submitting any upstream PR to `digital-asset/canton` — these files are
review aids, not part of the contribution.

## Contents

| Path | Purpose |
|---|---|
| [`openapi-3.0/openapi.yaml`](openapi-3.0/openapi.yaml) | OpenAPI **3.0.3** YAML generated from the annotated protos via `buf.build/community/google-gnostic-openapi:v0.7.0`. Directly comparable to the existing `community/ledger/ledger-json-api/src/test/resources/json-api-docs/openapi.yaml` (also 3.0.3). |
| [`openapi-3.0/buf.gen.yaml`](openapi-3.0/buf.gen.yaml) | The exact `buf generate` config. |
| [`swagger-2.0/canton-ledger-api.swagger.yaml`](swagger-2.0/canton-ledger-api.swagger.yaml) | Swagger **2.0** YAML generated via `buf.build/grpc-ecosystem/openapiv2:v2.28.0` — same plugin as the upstream CommandService experiment, this time merged across every annotated service. |
| [`swagger-2.0/buf.gen.yaml`](swagger-2.0/buf.gen.yaml) | The exact `buf generate` config. |
| [`coverage-comparison/`](coverage-comparison/) | Sorted path inventories and the diff between the JSON API spec and the proto-derived spec after path-parameter name normalization. |
| [`reproduce.sh`](reproduce.sh) | One-shot script regenerating every artefact in this directory. |

## Coverage summary

| Metric | JSON API yaml | Proto-derived yaml |
|---|---|---|
| Distinct paths | 51 | 45 |
| Schemas | 199 (n/a in jsonapi yaml — uses inline) | 199 named, package-qualified |
| `Empty1`..`Empty10` numbered duplicate schemas | present | **0** |
| `additionalProperties: true` untyped maps | 0 | 1 (legitimate `google.protobuf.Any`) |

After normalizing path-parameter names (`{user_id}` ↔ `{user-id}`,
`{identity_provider_id}` ↔ `{idp-id}`, `{parties}` ↔ `{party}`, etc.):

- **9 paths only in the JSON API yaml** — all deliberately skipped on the
  proto side, listed in [`coverage-comparison/jsonapi-only.txt`](coverage-comparison/jsonapi-only.txt):
  - `/v2/authenticated-user` — custom JSON-only endpoint, no gRPC backing.
  - 8 deprecated legacy aliases targeted for 3.5.0 removal
    (`/v2/commands/submit-and-wait-for-transaction-tree`,
    `/v2/package-vetting`, `/v2/updates/flats`, `/v2/updates/trees`,
    `/v2/updates/transaction-by-id`, `/v2/updates/transaction-by-offset`,
    `/v2/updates/transaction-tree-by-id/{update-id}`,
    `/v2/updates/transaction-tree-by-offset/{offset}`).
- **0 paths only in the proto-derived yaml** — every annotated RPC has a
  matching JSON API route.

## Known route deviations from tapir

A single intentional change: `StateService.GetActiveContractsPage` is
annotated as **POST** (not GET, like tapir does today).
`grpc-ecosystem/openapiv2` rejects GET-with-body
(`must not set request body when http method is GET`), and the request
carries a required `EventFormat` message that does not flatten cleanly
to query parameters. POST is the canonical mapping for a non-trivial
body. See the `experiment: switch GetActiveContractsPage to POST` commit
for context.

## How to reproduce

```bash
# from the repo root, on this branch:
bash http-annotations-evidence/reproduce.sh
```

The script:

1. fetches `google/api/annotations.proto`, `google/api/http.proto`, and
   `google/rpc/status.proto` into the workspace location that
   `buf.work.yaml` already references
   (`community/lib/google-common-protos-scala/target/protobuf_external/`);
2. runs `buf generate` twice (once per format) targeting every annotated
   v2 service proto;
3. regenerates `coverage-comparison/*.txt` from both yamls.

Re-running the script over a clean checkout of this branch must produce
byte-identical files to those committed here.
