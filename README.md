# mcl-mail

**Async mailboxes for the Macula mesh: an agent leaves work for a citizen who is not online right now**

## What it does

A citizen (a person, an agent or a service, anything with a macula node
identity) keeps a mailbox here. Anyone can leave a letter in it while the
citizen is offline; the citizen reads, replies and archives when they are back.

Seven request-and-reply procedures, served under the org `mcl-mail`:

| Procedure | Payload | Reply | Acts on |
|-----------|---------|-------|---------|
| `mcl-mail/initiate_mailbox` | none | `#{}` | the caller's mailbox comes into being |
| `mcl-mail/open_mailbox` | none | `#{}` | the caller's mailbox starts receiving mail |
| `mcl-mail/deposit_letter` | `to_citizen_did` (64 hex), `subject`, `body`, optional `reply_letter_id` | `letter_id` | the recipient's mailbox; the sender is the caller |
| `mcl-mail/reply_to_letter` | `letter_id`, `subject`, `body` | `letter_id` | marks the letter answered in the caller's mailbox, deposits the reply with the original sender |
| `mcl-mail/archive_letter` | `letter_id` | `letter_id` | the caller's mailbox |
| `mcl-mail/get_mailbox` | none | `letters`, unread first | the caller's unarchived letters, marked read once fetched |
| `mcl-mail/get_letter` | `letter_id` | `letter` | one of the caller's letters, marked read once fetched |

A refusal comes back as the call's error with a short reason: `no_caller`,
`invalid_to_citizen_did`, `not_initiated`, `already_initiated`, `already_open`,
`mailbox_not_opened`, `mailbox_closed`, `mailbox_archived`, `letter_not_found`,
`letter_archived`, `missing_letter_id`, `not_found`, `replied_but_not_delivered`.

A letter goes out as `letter_id`, `from_did` (64 hex), `subject`, `body`,
`deposited_at` (unix ms), `read`, `replied`, `archived` (each 0 or 1), and
`reply_letter_id` when it answers another. Text is CBOR text, never bytes.

### Who a call acts as

**Every procedure acts as the CALL's caller.** macula 12 puts `caller` on each
inbound CALL: the node id of the identity key that signed the request, verified
by every station on the path and again by this provider, and written over any
`caller` the payload sends. A citizen's DID is that same node id. So a citizen
can only open, read, reply from and archive in their own mailbox, and a letter's
`from_did` is whoever signed the deposit, never something they typed. No
separate ownership proof is needed, and none is accepted.

A deposit needs the recipient's mailbox to be initiated and open. Nothing
opens a mailbox on a citizen's behalf, so a stranger cannot bring a mailbox into
being for somebody who never asked for one.

### How it is built

An umbrella of four apps, one per department:

- `guide_mailbox_lifecycle` (CMD): the mailbox aggregate, one event-sourced
  stream per citizen (`mailbox-<128-bit digest of the DID>`), in the reckon-db
  store `mcl_mail_store`. Nine desks: initiate, open, close, archive and
  unarchive a mailbox; deposit, mark read, reply to and archive a letter.
  Status is bit flags (`mailbox_status.hrl`). The five CMD responders live
  beside their desks.
- `project_mailboxes` (PRJ): `letter_lifecycle_to_mailboxes` projects the four
  letter events into a barrel_docdb read model, one document per letter.
- `query_mailboxes` (QRY): `get_mailbox` and `get_letter`, read from that model.
- `mcl_mail`: the `mcl_om_service` contract.

close, archive and unarchive a mailbox are tested desks with no procedure yet:
no client needs them. Marking a letter read is folded into the two reads.

## Running it

    rebar3 compile
    rebar3 eunit
    rebar3 lint
    rebar3 dialyzer

    scripts/health.sh                      # against a running node

Building the image needs a Rust toolchain, because macula ships a QUIC NIF and
the alpine build compiles it from source rather than fetching one linked against
a different libc.

    podman build -t mcl-mail -f Containerfile .

## Configuration

| Variable | Default | Meaning |
|----------|---------|---------|
| `MCL_REALM` | required | 64-hex realm tag, the `sha256` of the realm's name. No default: a service that guesses its realm announces itself where nobody can attribute it. |
| `MCL_REALM_KEY` | required | The realm's public signing key, hex encoded: the **trust anchor**, not an identifier. Every org-namespaced advertisement is verified against it, so without it nothing resolves, the boot claim never reaches the realm, and the service stays green while unreachable. Public material, not a secret. |
| `MACULA_STATION_SEEDS` | required | Station hosts to dial, `host[:port]`, comma-separated. No default: naming a realm costs nothing, dialling a production station from every dev clone does. |
| `MACULA_STATION_NODE_IDS` | required | The matching 64-hex station node ids, comma-separated, index-paired with the seeds. The dial is pinned (D5): mcl_om refuses to boot a pool with an unpinned seed. |
| `MCL_HEALTH_PORT` | `8496` | Health endpoint. Host networking makes a collision a silent bind failure, so check the host before changing.  |
| `MCL_NODE_NAME` | `mcl_mail` | Erlang node name. |
| `MCL_NODE_HOST` | `127.0.0.1` | Erlang node host. |
| `MCL_COOKIE` | `mcl_mail` | Erlang cookie. |
| `MCL_DATA_DIR` | `/tmp/mcl_mail` | Where the store (`mcl_mail_store/`) and the read model (`mcl_mail/`) live. The compose file sets `/data` and mounts a volume there. |

`deploy/docker-compose.yml` runs it, and carries what the service knows about
itself. If you deploy through something else, let that carry **placement**: which
host, which station, which realm, which secret store. Keeping the two apart is
what stops a config table in a README and the real environment drifting.

## Deployment

The image has two channels. A push to `main` publishes
`ghcr.io/macula-services/mcl-mail:latest`, the deploy channel: a host that follows
`:latest` deploys every merge. A `v*` tag publishes its own version and nothing
else, the rollback archive: pin a host to one to roll back. A push that changes
only documentation builds no image (`scripts/is_image_push.sh`).

The service's org, the `<org>` in every procedure it offers (`<org>/<name>`), is
this repository's name, fixed in `config/sys.config.src`. The realm's grant names
it; without an org mcl_om advertises nothing.

Two things CI cannot do for you, both of which have bitten:

1. The registry package may be created **private**, and the pull then fails on
   the host with a bare `unauthorized` that names nothing. Check it after the
   first build. On ghcr the `org.opencontainers.image.source` label in the
   Containerfile is what links the package to the repository.
2. The host needs `MCL_REALM` and the pinned station pair supplied from
   somewhere they are not committed.

## The service contract

Six callbacks in `mcl_mail_service`, all required, all resolved **by name** by
`mcl_om` at startup on a live node. The `-behaviour(mcl_om_service)`
attribute turns a missing one into a compile error rather than an `undef` where
nobody is watching, and the eunit suite guards the attribute itself.

### The store and the read model

The service owns a `reckon-db` store, `mcl_mail_store`, and a barrel_docdb read
model, `mcl_mail`. It exports `store_id/0`, `data_dir/0` and `read_model_id/0`,
so `mcl_om:boot/1` opens both, and the store's evoq subscription, before
`start/1` fires. `config/sys.config.src` carries the `evoq` adapter block that
boot requires.

⚠ **The store id is written in two places**, `store_id/0` and the `evoq` block,
and nothing makes them agree by itself. A test compares them, along with a
second one asserting the `evoq` block is present at all. Keep both.

⚠ **`deploy/docker-compose.yml` mounts a volume, and on a node it must.** Without
it the mail lives inside the container and every recreate destroys it, which is
the same as not keeping any.

The store is node-local: one node serves the mail it holds.

## Licence

Apache-2.0.
