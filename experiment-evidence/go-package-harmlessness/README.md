# Proof that `option go_package` is harmless for existing Canton consumers

## Why we needed `go_package` in the first place

Every off-the-shelf OpenAPI generator in the protobuf ecosystem is written in Go: `protoc-gen-openapiv2` (grpc-ecosystem/grpc-gateway), `protoc-gen-openapi` (google/gnostic), the buf-published variants of both. They walk the `FileDescriptorSet` for the target service and, for every `.proto` in the transitive closure, look up its declared Go import path so the generator can emit per-file artefacts.

When the option is missing the plugin fails fast:

```
unable to determine Go import path for "com/daml/ledger/api/v2/value.proto"

Please specify either:
  • a "go_package" option in the .proto source file, or
  • a "M" argument on the command line.
```

This is enforced even when no Go code is being emitted — it is a hard precondition for *running* the plugin. Canton's protos currently declare `csharp_namespace`, `java_package`, `java_outer_classname` but not `go_package`, because Canton has no Go target. So every Go-based OpenAPI tool refuses to run against the proto set until that gap is filled.

The fix is a one-line `option go_package = "..."` per proto file, sitting alongside the existing language-target options. Three things to prove:

1. The added option is the **only** semantic change to the compiled `FileDescriptorSet`.
2. Canton's actual codegen pipeline **never reads** `go_package`, so the option cannot affect generated Scala / Java / C# output.
3. The option is **inert by design** in protobuf — each language has its own `FileOptions` field; consumers read only their own.

The artefacts below establish each claim with byte-level evidence.

## Artefacts

| File | What it proves |
|---|---|
| `version_service.proto.before` | Verbatim copy of the proto **as it exists upstream** in `digital-asset/canton@v3.5.1-rc3`. |
| `version_service.proto.after` | Verbatim copy of the proto **after our change**. |
| `version_service.proto.diff` | Unified diff of the two source files. One added line: `+option go_package = "...";`. |
| `version_service.before.descriptor.txt` | Full textproto-decoded `FileDescriptorProto` produced by `buf build` on the upstream proto. |
| `version_service.after.descriptor.txt` | Same, on the patched proto. |
| `version_service.before.descriptor.nosourceinfo.txt` | Same as above with `source_code_info` stripped. `source_code_info` only carries source-line spans for IDE tooling; it inevitably shifts when any line is added or removed and is not semantically meaningful. |
| `version_service.after.descriptor.nosourceinfo.txt` | Same. |
| `version_service.descriptor.semantic.diff` | Unified diff of the two `.nosourceinfo` descriptors. **One added line: `+  go_package: "..."` inside the `options { }` block, alongside `java_package`, `java_outer_classname`, `csharp_namespace`. Nothing else changes — no message field, no service method, no enum, no import.** |
| `canton-build-targets.txt` | `grep` of `project/BuildCommon.scala` for every `PB.targets` declaration. Every entry routes to `scalapb.gen` or `PB.gens.java`. No `gen_go`, no `protoc-gen-go`, no Go plugin anywhere. Canton's build pipeline literally cannot read the `go_package` option, because no Go plugin is invoked. |

## Why this is sound — the protobuf-language guarantee

`google/protobuf/descriptor.proto` defines `FileOptions` as a flat message with one field per language target:

```proto
message FileOptions {
  optional string java_package         = 1;
  optional string java_outer_classname = 8;
  ...
  optional string go_package           = 11;
  ...
  optional string csharp_namespace     = 37;
  optional string swift_prefix         = 39;
  optional string php_class_prefix     = 40;
  ...
}
```

Each consuming plugin reads only the field assigned to its language. `protoc-gen-java` reads `java_package` and ignores the rest. `protoc-gen-go` reads `go_package` and ignores the rest. ScalaPB reads its own dedicated `scalapb.options` extension and ignores all of the language-target fields. Adding a sibling field to `options {}` has no effect on a plugin that does not read that field — this is the whole point of how proto FileOptions are structured.

The semantic diff above demonstrates this empirically: the **only** change to the compiled descriptor is one new sibling field inside `options {}`. Every other byte of the descriptor — message definitions, service methods, RPC signatures, imports, dependencies — is identical.

## Reproduce

```bash
# from canton repo root, on this branch:
git checkout HEAD~1 -- community/ledger-api-proto/src/main/protobuf/com/daml/ledger/api/v2/version_service.proto
( cd community/ledger-api-proto/src/main/protobuf && \
  buf build --path com/daml/ledger/api/v2/version_service.proto -o /tmp/version_service.before.binpb )
git checkout HEAD -- community/ledger-api-proto/src/main/protobuf/com/daml/ledger/api/v2/version_service.proto
( cd community/ledger-api-proto/src/main/protobuf && \
  buf build --path com/daml/ledger/api/v2/version_service.proto -o /tmp/version_service.after.binpb )

python3 - <<'EOF'
from google.protobuf import descriptor_pb2
for state in ('before', 'after'):
    fds = descriptor_pb2.FileDescriptorSet()
    with open(f'/tmp/version_service.{state}.binpb', 'rb') as f:
        fds.ParseFromString(f.read())
    for fproto in fds.file:
        if fproto.name.endswith('version_service.proto'):
            fproto.ClearField('source_code_info')
            open(f'/tmp/version_service.{state}.txt', 'w').write(str(fproto))
EOF

diff -u /tmp/version_service.before.txt /tmp/version_service.after.txt
```

The diff is the same one-line addition shown in `version_service.descriptor.semantic.diff`.
