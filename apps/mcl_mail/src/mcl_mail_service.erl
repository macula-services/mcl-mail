%% @doc The mcl_om service contract for mcl-mail.
%%
%% Async mailboxes: an agent leaves work for a citizen who is not online, and
%% the citizen reads it when they are. Seven request-and-reply procedures,
%% registered by mcl_om as `mcl-mail/<name>'. Every one acts as the CALL's
%% wire-authenticated caller (see `mailbox_citizen'): a citizen initiates,
%% opens, reads, replies from and archives in their OWN mailbox, and the
%% sender of a deposited letter is whoever signed the deposit.
%%
%% SIX CALLBACKS, ALL REQUIRED. The store is this service's own: event_store/0
%% describes it and mcl_mail_app opens it before mcl_om:boot/1 (mcl_om opens
%% none from 0.35, mcl-om#10; NOT store_id/0 and data_dir/0, a pair it would
%% warn about). mcl_om resolves them BY NAME at startup, on a
%% live node, so a service that forgets one dies with `undef' where nobody is
%% watching. The `-behaviour' attribute below is what turns that into a compile
%% error instead, and the test suite guards the attribute itself.
-module(mcl_mail_service).

-behaviour(mcl_om_service).

-export([info/0, start/1, stop/1, health/0, capabilities/0, identity_spec/0]).
%% ⚠ `config/sys.config.src' MUST CARRY THE `evoq' BLOCK. mcl_mail_store starts
%% a per-store evoq subscription that reads the global log, and that crashes on
%% `{not_configured, event_store_adapter}' without it. evoq starts as a
%% release-boot application before any service's `start/2' runs, so nothing can
%% inject it later. A sibling put two of three fleet nodes into a boot-crash
%% loop this exact way.
-export([event_store/0]).
info() ->
    #{name => <<"mcl-mail">>,
      version => <<"0.3.1">>,
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

%% @doc The reckon-db store this service owns, as mcl_mail_app opens it.
%%
%% `id': ⚠ NAMED IN TWO PLACES, here and in the `evoq' block of
%% `config/sys.config.src', and nothing makes them agree by itself. Disagreeing
%% opens one store and addresses another. A test compares the two. Every CMD
%% desk names the same store when it dispatches.
%%
%% `dir': where it lives on disk, the store at <dir>/mcl_mail_store.
%% ⚠ DEFAULTS TO A PATH INSIDE THE CONTAINER AND MUST NOT STAY THERE ON A NODE.
%% The fleet keeps application data on its `/bulk' drives and boots from a small
%% eMMC, so `deploy/docker-compose.yml' mounts a volume and sets this. The default
%% is what a laptop wants; a container without the mount loses its record on every
%% recreate, which is the same as not keeping one.
-spec event_store() -> #{id := atom(), dir := string(), indexes := [term()],
                         mode := single | cluster, integrity := disabled | map()}.
event_store() ->
    #{id => mcl_mail_store,
      dir => chosen(os:getenv("MCL_DATA_DIR")),
      indexes => [],
      mode => single,
      integrity => disabled}.

chosen(false) -> "/tmp/mcl_mail";
chosen("") -> "/tmp/mcl_mail";
chosen(Path) -> Path.

