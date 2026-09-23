%%% @doc The five CMD responders act as the CALL's caller, and only as it.
%%%
%%% The mailbox a call opens, reads from or replies out of is the caller's
%%% own; the sender of a deposited letter is the caller. None of them takes a
%%% citizen's identity from the payload, so none can be pointed at somebody
%%% else's mailbox. meck stands in for each desk's dispatch, so these see the
%%% exact command a responder hands on without a store.
-module(mailbox_responders_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ALICE, <<16#a1:256>>).
-define(BOB, <<16#b0:256>>).
-define(MALLORY, <<16#ee:256>>).

hex(Did) -> {text, binary:encode_hex(Did, lowercase)}.

%% Each case gets fresh mocks of the dispatches it may reach; the handed-on
%% command is read back from meck's history.
with_dispatch(Mod, Result, Test) ->
    meck:new(Mod, [passthrough]),
    meck:expect(Mod, dispatch, fun(_Cmd) -> Result end),
    try Test() after meck:unload(Mod) end.

dispatched(Mod) ->
    [Cmd] = [C || {_Pid, {_M, dispatch, [C]}, _Ret} <- meck:history(Mod)],
    Cmd.

not_dispatched(Mod) ->
    ?assertEqual([], [C || {_Pid, {_M, dispatch, [C]}, _Ret} <- meck:history(Mod)]).

ok_events() -> {ok, 1, [#{}]}.

%%--------------------------------------------------------------------
%% No caller, no call
%%--------------------------------------------------------------------

every_responder_refuses_a_payload_without_a_caller_test_() ->
    [?_assertEqual({error, no_caller, []}, R:handle_request(#{letter_id => {text, <<"l1">>},
                                                              to_citizen_did => hex(?BOB)}, []))
     || R <- [initiate_mailbox_responder, open_mailbox_responder, deposit_letter_responder,
              reply_to_letter_responder, archive_letter_responder]].

%%--------------------------------------------------------------------
%% initiate_mailbox / open_mailbox
%%--------------------------------------------------------------------

initiate_acts_on_the_callers_own_mailbox_test() ->
    with_dispatch(maybe_initiate_mailbox, ok_events(), fun() ->
        Payload = #{caller => ?ALICE, citizen_did => hex(?MALLORY)},
        ?assertEqual({reply, #{}, []}, initiate_mailbox_responder:handle_request(Payload, [])),
        ?assertEqual(?ALICE, initiate_mailbox_v1:get_citizen_did(dispatched(maybe_initiate_mailbox)))
    end).

open_acts_on_the_callers_own_mailbox_test() ->
    with_dispatch(maybe_open_mailbox, ok_events(), fun() ->
        Payload = #{caller => ?ALICE, citizen_did => hex(?MALLORY)},
        ?assertEqual({reply, #{}, []}, open_mailbox_responder:handle_request(Payload, [])),
        ?assertEqual(?ALICE, open_mailbox_v1:get_citizen_did(dispatched(maybe_open_mailbox)))
    end).

a_refused_command_is_the_calls_error_test() ->
    with_dispatch(maybe_open_mailbox, {error, already_open}, fun() ->
        ?assertEqual({error, already_open, []},
                     open_mailbox_responder:handle_request(#{caller => ?ALICE}, []))
    end).

%%--------------------------------------------------------------------
%% deposit_letter
%%--------------------------------------------------------------------

the_sender_of_a_deposit_is_the_caller_not_the_payload_test() ->
    with_dispatch(maybe_deposit_letter, ok_events(), fun() ->
        Payload = #{caller => ?ALICE, to_citizen_did => hex(?BOB), from_did => hex(?MALLORY),
                    subject => {text, <<"hello">>}, body => {text, <<"can you build X?">>}},
        {reply, #{letter_id := {text, LetterId}}, []} =
            deposit_letter_responder:handle_request(Payload, []),
        Cmd = dispatched(maybe_deposit_letter),
        ?assertEqual(?ALICE, deposit_letter_v1:get_from_did(Cmd)),
        ?assertEqual(?BOB, deposit_letter_v1:get_to_citizen_did(Cmd)),
        ?assertEqual(<<"hello">>, deposit_letter_v1:get_subject(Cmd)),
        ?assertEqual(<<"can you build X?">>, deposit_letter_v1:get_body(Cmd)),
        ?assertEqual(LetterId, deposit_letter_v1:get_letter_id(Cmd))
    end).

a_deposit_without_a_readable_recipient_is_refused_before_dispatch_test() ->
    with_dispatch(maybe_deposit_letter, ok_events(), fun() ->
        ?assertEqual({error, invalid_to_citizen_did, []},
                     deposit_letter_responder:handle_request(#{caller => ?ALICE}, [])),
        ?assertEqual({error, invalid_to_citizen_did, []},
                     deposit_letter_responder:handle_request(
                       #{caller => ?ALICE, to_citizen_did => {text, <<"bob">>}}, [])),
        not_dispatched(maybe_deposit_letter)
    end).

a_deposit_into_a_closed_mailbox_says_so_test() ->
    with_dispatch(maybe_deposit_letter, {error, mailbox_closed}, fun() ->
        ?assertEqual({error, mailbox_closed, []},
                     deposit_letter_responder:handle_request(
                       #{caller => ?ALICE, to_citizen_did => hex(?BOB)}, []))
    end).

%%--------------------------------------------------------------------
%% reply_to_letter / archive_letter
%%--------------------------------------------------------------------

a_reply_comes_out_of_the_callers_own_mailbox_test() ->
    with_dispatch(maybe_reply_to_letter, ok_events(), fun() ->
        Payload = #{caller => ?ALICE, citizen_did => hex(?MALLORY),
                    letter_id => {text, <<"l1">>}, subject => {text, <<"re: plans">>},
                    body => {text, <<"agreed">>}},
        ?assertEqual({reply, #{letter_id => {text, <<"l1">>}}, []},
                     reply_to_letter_responder:handle_request(Payload, [])),
        Cmd = dispatched(maybe_reply_to_letter),
        ?assertEqual(?ALICE, reply_to_letter_v1:get_citizen_did(Cmd)),
        ?assertEqual(<<"l1">>, reply_to_letter_v1:get_letter_id(Cmd)),
        ?assertEqual(<<"agreed">>, reply_to_letter_v1:get_body(Cmd))
    end).

a_reply_marked_but_not_delivered_says_so_test() ->
    with_dispatch(maybe_reply_to_letter, {error, {replied_but_delivery_failed, mailbox_closed}},
                  fun() ->
        ?assertEqual({error, replied_but_not_delivered, []},
                     reply_to_letter_responder:handle_request(
                       #{caller => ?ALICE, letter_id => {text, <<"l1">>}}, []))
    end).

an_archive_acts_on_the_callers_own_mailbox_test() ->
    with_dispatch(maybe_archive_letter, ok_events(), fun() ->
        Payload = #{caller => ?ALICE, citizen_did => hex(?MALLORY), letter_id => {text, <<"l1">>}},
        ?assertEqual({reply, #{letter_id => {text, <<"l1">>}}, []},
                     archive_letter_responder:handle_request(Payload, [])),
        ?assertEqual(?ALICE, archive_letter_v1:get_citizen_did(dispatched(maybe_archive_letter)))
    end).

a_letter_command_without_a_letter_id_is_refused_before_dispatch_test() ->
    with_dispatch(maybe_archive_letter, ok_events(), fun() ->
        ?assertEqual({error, missing_citizen_did_or_letter_id, []},
                     archive_letter_responder:handle_request(#{caller => ?ALICE}, [])),
        not_dispatched(maybe_archive_letter)
    end).
