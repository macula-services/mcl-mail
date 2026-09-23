# Changelog

All notable changes to this project are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- On `mcl_om` 0.27, which no longer brings `barrel_docdb`. The service declares
  it itself, and `project_mailboxes` opens the letter read model when it starts,
  before its projection runs.
- barrel_docdb's system database lives on the data volume. Its default,
  `/tmp/barrel_data`, is inside the container.
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
