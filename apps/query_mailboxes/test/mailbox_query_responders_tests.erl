%%% @doc get_mailbox and get_letter read the CALLER's own mail, and only it.
%%%
%%% A mailbox's contents are one citizen's private data. The mailbox read is
%%% the caller's, whatever the payload names, and reading marks what it
%%% returned read. meck stands in for the read model and the mark-read
%%% dispatch, so these need no store.
-module(mailbox_query_responders_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ALICE, <<16#a1:256>>).
-define(BOB, <<16#b0:256>>).
-define(MALLORY, <<16#ee:256>>).

hex(Did) -> {text, binary:encode_hex(Did, lowercase)}.

letter(LetterId, Read) ->
    #{<<"id">> => LetterId, <<"citizen_did">> => ?ALICE, <<"letter_id">> => LetterId,
      <<"from_did">> => ?BOB, <<"subject">> => <<"hello">>, <<"body">> => <<"can you build X?">>,
      <<"deposited_at">> => 1000, <<"read">> => Read, <<"replied">> => false,
      <<"archived">> => false}.

with_mocks(Test) ->
    meck:new(mailboxes_read_model, [passthrough]),
    meck:new(maybe_mark_letter_read, [passthrough]),
    meck:expect(maybe_mark_letter_read, dispatch, fun(_Cmd) -> {ok, 1, [#{}]} end),
    try Test()
    after
        meck:unload(maybe_mark_letter_read),
        meck:unload(mailboxes_read_model)
    end.

marked_read() ->
    [{mark_letter_read_v1:get_citizen_did(C), mark_letter_read_v1:get_letter_id(C)}
     || {_Pid, {_M, dispatch, [C]}, _Ret} <- meck:history(maybe_mark_letter_read)].

every_read_refuses_a_payload_without_a_caller_test_() ->
    [?_assertEqual({error, no_caller, []},
                   R:handle_request(#{letter_id => {text, <<"l1">>}}, []))
     || R <- [get_mailbox_by_citizen_responder, get_letter_by_id_responder]].

get_mailbox_lists_the_callers_mailbox_whatever_the_payload_names_test() ->
    with_mocks(fun() ->
        meck:expect(mailboxes_read_model, list_unarchived,
                    fun(?ALICE) -> [letter(<<"l1">>, false), letter(<<"l2">>, true)] end),
        {reply, #{letters := [First, Second]}, []} =
            get_mailbox_by_citizen_responder:handle_request(
              #{caller => ?ALICE, citizen_did => hex(?MALLORY)}, []),
        ?assertEqual([?ALICE], [D || {_P, {_M, list_unarchived, [D]}, _R}
                                         <- meck:history(mailboxes_read_model)]),
        %% The read flag as it was when fetched, so a caller sees what is new.
        ?assertEqual(0, maps:get(read, First)),
        ?assertEqual(1, maps:get(read, Second)),
        %% And only the unread one is marked read, in the caller's mailbox.
        ?assertEqual([{?ALICE, <<"l1">>}], marked_read())
    end).

get_letter_reads_from_the_callers_mailbox_test() ->
    with_mocks(fun() ->
        meck:expect(mailboxes_read_model, find,
                    fun(?ALICE, <<"l1">>) -> {ok, letter(<<"l1">>, false)} end),
        {reply, #{letter := Letter}, []} =
            get_letter_by_id_responder:handle_request(
              #{caller => ?ALICE, citizen_did => hex(?MALLORY), letter_id => {text, <<"l1">>}}, []),
        ?assertEqual({text, <<"l1">>}, maps:get(letter_id, Letter)),
        ?assertEqual([{?ALICE, <<"l1">>}], marked_read())
    end).

a_letter_the_caller_does_not_hold_is_not_found_test() ->
    with_mocks(fun() ->
        meck:expect(mailboxes_read_model, find, fun(_Did, _LetterId) -> {error, not_found} end),
        ?assertEqual({error, not_found, []},
                     get_letter_by_id_responder:handle_request(
                       #{caller => ?ALICE, letter_id => {text, <<"l9">>}}, [])),
        ?assertEqual([], marked_read())
    end).

get_letter_without_a_letter_id_is_a_bad_request_test() ->
    with_mocks(fun() ->
        ?assertEqual({error, missing_letter_id, []},
                     get_letter_by_id_responder:handle_request(#{caller => ?ALICE}, []))
    end).
