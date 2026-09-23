%% @doc The mcl_om service contract for mcl-mail.
%%
%% Async mailboxes: an agent leaves work for a citizen who is not online, and
%% the citizen reads it when they are. Seven request-and-reply procedures,
%% registered by mcl_om as `mcl-mail/<name>'. Every one acts as the CALL's
%% wire-authenticated caller (see `mailbox_citizen'): a citizen initiates,
%% opens, reads, replies from and archives in their OWN mailbox, and the
%% sender of a deposited letter is whoever signed the deposit.
%%
%% SIX CALLBACKS, ALL REQUIRED. mcl_om resolves them BY NAME at startup, on a
%% live node, so a service that forgets one dies with `undef' where nobody is
%% watching. The `-behaviour' attribute below is what turns that into a compile
%% error instead, and the test suite guards the attribute itself.
-module(mcl_mail_service).

-behaviour(mcl_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).
%% ==========================================================================
%% AND TWO OPTIONAL ONES, WHICH TURN THE STORE ON
%% ==========================================================================
%%
%% Generated because this service was scaffolded with `store=1'. Exporting
%% `store_id/0' and `data_dir/0' TOGETHER makes `mcl_om:boot/1' open a
%% reckon-db store before this module's `start/1' fires.
%%
%% ⚠ THE reckon-db APPLICATIONS RUN EITHER WAY. `reckon_db', `reckon_evoq',
%% `reckon_gater', `evoq', `khepri' and `ra' start with `mcl_om' whether these
%% callbacks exist or not. What the two add is a STORE: a data directory, an open
%% handle, and something written. A sibling service claimed for months that they
%% suppressed the whole stack while six of its thirty-one running applications
%% quietly disproved it.
%%
%% ⚠⚠ AND `config/sys.config.src' MUST CARRY THE `evoq' BLOCK, which is why it was
%% generated with one. mcl_om starts a per-store evoq subscription that reads
%% the global log, and that crashes on `{not_configured, event_store_adapter}'
%% without it. evoq starts as a release-boot application before any service's
%% `start/2' runs, so nothing can inject it later. A sibling put two of three
%% fleet nodes into a boot-crash loop this exact way.
-export([store_id/0, data_dir/0]).
%% ==========================================================================
%% AND A READ MODEL, alongside the store
%% ==========================================================================
%%
%% `project_mailboxes' writes the letter read model into this barrel_docdb
%% database and `query_mailboxes' reads it, both through mcl_om:read_model/0.
%% mcl_om:boot/1 opens it at data_dir/read_model_id before start/1 fires.
-export([read_model_id/0]).

info() ->
    #{name => <<"mcl-mail">>,
      version => <<"0.1.0">>,
      description => <<"Async mailboxes for the Macula mesh: an agent leaves work for a citizen who is not online right now">>}.

start(_Opts) -> mcl_mail_sup:start_link().

stop(_State) -> ok.

%% Nothing of the service's own can fail once its tree is up. Whether callers
%% can REACH it (each procedure's realm-issued D25 provider grant) is reported
%% by mcl_om's /health itself, combined with this verdict.
health() -> ok.

%% WHAT THIS SERVICE ANNOUNCES IT CAN DO, each entry a promise that something
%% answers. initiate/open/deposit change a mailbox; reply/archive act on the
%% caller's own letters; get_mailbox/get_letter disclose the caller's own mail
%% and mark it read. close_mailbox, archive_mailbox, unarchive_mailbox and
%% mark_letter_read are tested domain desks with no procedure of their own:
%% no client needs close or archive yet, and marking read is folded into the
%% two reads.
capabilities() ->
    [#{name => <<"initiate_mailbox">>, version => 1,
       handler => {initiate_mailbox_responder, []}},
     #{name => <<"open_mailbox">>, version => 1,
       handler => {open_mailbox_responder, []}},
     #{name => <<"deposit_letter">>, version => 1,
       handler => {deposit_letter_responder, []}},
     #{name => <<"reply_to_letter">>, version => 1,
       handler => {reply_to_letter_responder, []}},
     #{name => <<"archive_letter">>, version => 1,
       handler => {archive_letter_responder, []}},
     #{name => <<"get_mailbox">>, version => 1,
       handler => {get_mailbox_by_citizen_responder, []}},
     #{name => <<"get_letter">>, version => 1,
       handler => {get_letter_by_id_responder, []}}].

%% THE AUTHORITY THIS SERVICE ASKS THE REALM FOR, and deliberately nothing more.
%% Ask for exactly the topics you publish and subscribe to. mcl-mail publishes
%% and subscribes to none: its procedures are CALLs, each served under its own
%% D25 provider grant, so it asks for nothing.
%%
%% The scope is claimed now because it is the namespace every later resource
%% hangs under, and a scope costs nothing while a rename costs every deployed
%% peer.
identity_spec() ->
    #{scope => <<"mcl-mail">>,
      actions => [],
      resources => [],
      ttl_days => 30}.

%% ==========================================================================
%% The store
%% ==========================================================================

%% @doc The reckon-db store this service owns.
%%
%% ⚠ IT IS NAMED IN TWO PLACES, here and in the `evoq' block of
%% `config/sys.config.src', and nothing makes them agree by itself. Disagreeing
%% opens one store and addresses another. A generated test compares the two.
-spec store_id() -> atom().
store_id() -> mcl_mail_store.

%% @doc Where it lives on disk.
%%
%% ⚠ DEFAULTS TO A PATH INSIDE THE CONTAINER AND MUST NOT STAY THERE ON A NODE.
%% The fleet keeps application data on its `/bulk' drives and boots from a small
%% eMMC, so `deploy/docker-compose.yml' mounts a volume and sets this. The default
%% is what a laptop wants; a container without the mount loses its record on every
%% recreate, which is the same as not keeping one.
-spec data_dir() -> string().
data_dir() -> chosen(os:getenv("MCL_DATA_DIR")).

chosen(false) -> "/tmp/mcl_mail";
chosen("") -> "/tmp/mcl_mail";
chosen(Path) -> Path.

%% @doc The barrel_docdb database the letter read model lives in.
-spec read_model_id() -> binary().
read_model_id() -> <<"mcl_mail">>.
