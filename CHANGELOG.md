# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-10-07

### Changed

- **`/health` on a Unix socket, not a port (#5).** mcl_om 0.39's `health_socket`, `/run/mcl/health.sock` inside the container: no TCP health listener runs, the image's HEALTHCHECK uses `curl --unix-socket`, and nothing configures, exposes or passes a health port. `scripts/health.sh` asks the running container.
- **On macula 14.2 and mcl_om 0.38 (#5).** `~> 14.2` (at least 14.2.1, macula-io/macula#85) and `~> 0.38`, the current SDK base, so an SDK fix reaches this service with the rest. The sealing posture is unchanged.

### Changed

- **Nothing moves `:latest` any more** (macula-fleet#15). The `promote-latest` job is gone: macula-fleet
  pins each signed `v*` release by digest itself, once it verifies it was signed on that tag.

## [0.2.0] - 2026-10-05

- **On mcl_om 0.37.6 and macula 13.5.0** (`mcl_om ~> 0.37`, `macula ~> 13.5`, released versions only). mcl_om 0.37 brings
  the inbound guard pipeline (mcl-om#14); macula 13.5 adds `macula_record:decode_payload/1`, no wire
  change. This release is what the dev fleet's `:latest` follows: CI signs it, then moves `:latest`.

### Changed

- **The store is this service's own** (mcl-om#10). From mcl_om 0.35 on, mcl_om opens no store and
  brings no reckon-db or evoq application, so on mcl_om 0.37 nothing would start `reckon_db` or
  open a store. mcl-mail now declares `reckon_db`, `evoq` and `reckon_evoq` itself
  (`~> 5.11`, `~> 1.26`, `~> 2.7`), and `mcl_mail_app` opens the store with its own copy of the
  wiring (`mcl_mail_store`) before `mcl_om:boot/1`, after the three departments have started. The
  service describes the store as one `event_store/0` map instead of `store_id/0` and `data_dir/0`.

## [0.1.1] - 2026-09-28

### Fixed

- **The image is signed.** 0.1.0 shipped unsigned: `build-push.yml` had no
  attest job, so a box whose reconciler enforces signatures refuses it. The
  pushed digest now goes to macula-ci-images' `attest-image.yml`, pinned by
  full commit, which signs it keylessly and attests its SBOM and provenance,
  as mcl-echo's build does. A documentation-only push, which builds nothing,
  attests nothing.
- Every action the workflows run is pinned by full commit, the ones
  mcl-echo uses; they were pinned by moving tags. A test holds both.

## [0.1.0] - 2026-09-28

### Changed

- **The service requires the mesh** (`{mesh, required}`, mcl_om 0.33.1): a boot
  missing `MCL_REALM`, `MCL_REALM_KEY`, `MACULA_STATION_SEEDS` or
  `MACULA_STATION_NODE_IDS` stops and names each one. Before, an unset seed
  list booted a green node that answered `/health` and nothing else, and the
  other three stopped without naming the setting.
- Only `main` publishes `:latest` and only a `v*` tag publishes a version; a
  build of any other ref is refused, naming it.
- **On `mcl_om` 0.33.1 with macula 13.0.1** (and evoq 1.26.1; barrel_docdb
  resolves 1.7). The
  floors are mcl_om 0.33's own: with the looser `~> 12.2` before, rebar3 could
  pick mcl_om 0.33 with a macula 12 it does not support, and the info test now
  checks the pair down to the patch release.
- The image pair is pinned by its **dated tag and digest**
  (`macula-ci-otp-rocksdb` / `macula-pq-runtime-rocksdb` `20260928-1642`), and a
  test holds builder and runtime to one publication and CI to the same builder.
  The runtime image's packages are unchanged from the previous pin; both carry
  librocksdb 11.1.2 and OpenSSL 3.5.7.
- `deploy/docker-compose.yml` runs the image **by digest**
  (`MCL_MAIL_IMAGE_DIGEST`), as the fleet's own compose does; no `:latest`, no
  watchtower label. The fleet runs a `v*` release by digest; `:latest` is the tip
  of `main` and deploys nothing.
- The read-model tests keep barrel_docdb's system database in the test cache.
  barrel's own default, `data/barrel_docdb`, put it in the repository.

- **On `mcl_om` 0.28 with macula 12.2.** The service answers `mcl-mail/info`,
  which mcl_om adds (public facts: versions, labels, health word, procedures),
  and a test sends that reply through macula's frame codec and checks it names
  this service and the mcl_om 0.28 / macula 12.2 pair. 0.28 is the release
  macula 12.2 needs: under 12.2 an older mcl_om lets a failed publish
  announcement kill the publishing process.
- On `mcl_om` 0.27, which no longer brings `barrel_docdb`. The service declares
  it itself, and `project_mailboxes` opens the letter read model when it starts,
  before its projection runs.
- barrel_docdb's system database lives on the data volume. Its default,
  `data/barrel_docdb` relative to the working directory
  (`/app/data/barrel_docdb`), is inside the container.
- rocksdb links the system librocksdb (`-DWITH_SYSTEM_ROCKSDB=ON`) instead of
  compiling its bundled copy. The image builds in `macula-ci-otp-rocksdb` and
  runs on `macula-pq-runtime-rocksdb` (Debian trixie), CI runs in the same build
  image, all pinned by digest. It used to build and run on alpine.
- The boot claim carries `MCL_SERVICE_NAME=mcl-mail` and the deploying host's
  `MCL_BOX`, which the realm's Providers desk shows.

### Added

- The mailbox service on macula 12 and `mcl_om` 0.26.5: seven procedures under
  the org `mcl-mail` (`initiate_mailbox`, `open_mailbox`, `deposit_letter`,
  `reply_to_letter`, `archive_letter`, `get_mailbox`, `get_letter`), an
  event-sourced mailbox per citizen in the reckon-db store `mcl_mail_store`,
  and a barrel_docdb read model the two reads answer from.
- Every procedure acts as the CALL's wire-authenticated caller: a citizen
  touches only their own mailbox, and a letter's sender is whoever signed the
  deposit.
- Replies carry text as CBOR text and DIDs as hex text; refusals come back as
  the call's error with a short reason.
- CI runs `rebar3 dialyzer` beside lint and eunit.
