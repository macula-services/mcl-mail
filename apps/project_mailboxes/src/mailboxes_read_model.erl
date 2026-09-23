%%% @doc The letter read model every QRY desk reads through directly --
%%% `project_mailboxes' writes here, `query_mailboxes' reads here,
%%% neither ever touches `barrel_docdb' any other way. One document per
%%% letter, keyed by `{citizen_did, letter_id}', in the barrel_docdb
%%% database `mcl_mail', which project_mailboxes opens when it starts.
%%%
%%% Booleans (`read'/`archived') are plain Erlang terms here -- this is
%%% internal storage, not a mesh wire payload, so the org's "no bool on
%%% the wire" rule doesn't apply; `query_mailboxes' responders convert
%%% to `0'/`1' at the RPC boundary.
%%% @end
-module(mailboxes_read_model).

-define(DB, <<"mcl_mail">>).

-export([open/1, db/0]).
-export([upsert_deposited/2, mark_read/2, mark_replied/2, mark_archived/2]).
-export([find/2, list_unarchived/1, to_wire/1]).

%% @doc Open the read model under `DataDir', creating it on first boot and
%% reopening it after a restart. barrel_docdb's own system database is placed
%% by its app env (config/sys.config.src puts it on the data volume); this
%% places the read model itself.
-spec open(file:filename_all()) -> ok.
open(DataDir) ->
    Dir = filename:join(DataDir, binary_to_list(?DB)),
    ok = filelib:ensure_path(Dir),
    opened(barrel_docdb:create_db(?DB, #{data_dir => Dir})).

opened({ok, _Pid}) -> ok;
opened({error, already_exists}) -> ok.

%% @doc The read model's database name.
-spec db() -> binary().
db() -> ?DB.

-spec upsert_deposited(binary(), map()) -> ok.
upsert_deposited(CitizenDid, #{letter_id := LetterId} = Fields)
  when is_binary(CitizenDid), is_binary(LetterId) ->
    %% omit_undefined/1: barrel_docdb's automatic secondary indexing
    %% (barrel_ars_index:make_index_ops/3) crashes outright on an
    %% `undefined' field value (barrel_store_keys:encode_path_component/1
    %% has no clause for it) -- confirmed live, reply_letter_id is
    %% `undefined' on every non-reply deposit, which is most of them.
    Doc = omit_undefined(#{
        <<"id">> => doc_id(CitizenDid, LetterId),
        <<"citizen_did">> => CitizenDid,
        <<"letter_id">> => LetterId,
        <<"from_did">> => maps:get(from_did, Fields),
        <<"subject">> => maps:get(subject, Fields, <<"">>),
        <<"body">> => maps:get(body, Fields, <<"">>),
        <<"reply_letter_id">> => maps:get(reply_letter_id, Fields, undefined),
        <<"deposited_at">> => maps:get(deposited_at, Fields),
        <<"read">> => false,
        <<"replied">> => false,
        <<"archived">> => false
    }),
    put(Doc).

-spec mark_read(binary(), binary()) -> ok.
mark_read(CitizenDid, LetterId) -> flagged(CitizenDid, LetterId, <<"read">>).

-spec mark_replied(binary(), binary()) -> ok.
mark_replied(CitizenDid, LetterId) -> flagged(CitizenDid, LetterId, <<"replied">>).

-spec mark_archived(binary(), binary()) -> ok.
mark_archived(CitizenDid, LetterId) -> flagged(CitizenDid, LetterId, <<"archived">>).

flagged(CitizenDid, LetterId, Flag) ->
    set_flag(get_doc(doc_id(CitizenDid, LetterId)), Flag).

set_flag({ok, Doc}, Flag) -> put(Doc#{Flag => true});
set_flag({error, not_found}, _Flag) -> ok.

-spec find(binary(), binary()) -> {ok, map()} | {error, not_found}.
find(CitizenDid, LetterId) ->
    get_doc(doc_id(CitizenDid, LetterId)).

%% @doc Every unarchived letter for a citizen, unread first, then
%% newest deposited_at first. A per-citizen fold over the whole
%% database (no secondary index) -- correct and simple at this
%% service's current scale; revisit with a barrel_docdb index only
%% if a real citizen's mailbox ever makes this fold slow.
-spec list_unarchived(binary()) -> [map()].
list_unarchived(CitizenDid) ->
    {ok, Rows} = barrel_docdb:fold_docs(?DB, fun(Doc, Acc) -> collect(CitizenDid, Doc, Acc) end, []),
    lists:sort(fun newer_unread_first/2, Rows).

collect(CitizenDid, #{<<"citizen_did">> := CitizenDid, <<"archived">> := false} = Doc, Acc) ->
    {ok, [Doc | Acc]};
collect(_CitizenDid, _Doc, Acc) ->
    {ok, Acc}.

newer_unread_first(#{<<"read">> := ReadA, <<"deposited_at">> := AtA},
                   #{<<"read">> := ReadB, <<"deposited_at">> := AtB}) ->
    rank(ReadA, AtA) =< rank(ReadB, AtB).

rank(false, At) -> {0, -At};
rank(true, At) -> {1, -At}.

%% @doc A stored letter, shaped for an RPC reply. Text goes out `{text, Bin}',
%% a CBOR text string (a bare binary is a byte string, and a non-BEAM client
%% receives bytes). The sender's DID goes out as hex text, the form a client
%% names a recipient in, so a reply can go straight back to it. Flags go out
%% `0'/`1' (no booleans on the wire); internal storage above keeps plain
%% Erlang terms. `undefined' fields are omitted.
-spec to_wire(map()) -> map().
to_wire(Doc) ->
    omit_undefined(#{
        letter_id => text(maps:get(<<"letter_id">>, Doc)),
        from_did => mailbox_citizen:to_wire(maps:get(<<"from_did">>, Doc)),
        subject => text(maps:get(<<"subject">>, Doc)),
        body => text(maps:get(<<"body">>, Doc)),
        reply_letter_id => text(maps:get(<<"reply_letter_id">>, Doc, undefined)),
        deposited_at => maps:get(<<"deposited_at">>, Doc),
        read => bit(maps:get(<<"read">>, Doc)),
        replied => bit(maps:get(<<"replied">>, Doc)),
        archived => bit(maps:get(<<"archived">>, Doc))
    }).

text(undefined) -> undefined;
text(Bin) when is_binary(Bin) -> {text, Bin}.

bit(true) -> 1;
bit(false) -> 0.

omit_undefined(Map) ->
    maps:filter(fun(_K, V) -> V =/= undefined end, Map).

doc_id(CitizenDid, LetterId) ->
    <<(binary:encode_hex(CitizenDid, lowercase))/binary, ":", LetterId/binary>>.

get_doc(Id) ->
    barrel_docdb:get_doc(?DB, Id).

put(Doc) ->
    {ok, _} = barrel_docdb:put_doc(?DB, Doc),
    ok.
