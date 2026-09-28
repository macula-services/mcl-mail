# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
