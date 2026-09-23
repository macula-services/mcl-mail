%%% @doc The letter read model on a real barrel_docdb, opened exactly the way
%%% project_mailboxes opens it at start: a fresh directory per test.
%%%
%%% The directory name carries wall-clock time as well as a unique integer:
%%% `erlang:unique_integer/1' is unique only within one VM, and each
%%% `rebar3 eunit' run is a fresh VM, so an integer-only name could reopen a
%%% crashed run's leftover files.
-module(mailboxes_read_model_store_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ALICE, <<16#a1:256>>).
-define(BOB, <<16#b0:256>>).

store_test_() ->
    {foreach, fun open/0, fun close/1,
     [fun a_deposited_letter_is_listed_unread_and_found/1,
      fun a_read_letter_is_listed_after_the_unread_ones/1,
      fun an_archived_letter_is_found_but_not_listed/1,
      fun reopening_an_existing_read_model_is_fine/1]}.

open() ->
    {ok, _} = application:ensure_all_started(barrel_docdb),
    Dir = filename:join(filename:basedir(user_cache, "mcl-mail-test"),
                        integer_to_list(erlang:system_time(microsecond)) ++ "_" ++
                            integer_to_list(erlang:unique_integer([positive]))),
    ok = mailboxes_read_model:open(Dir),
    Dir.

close(Dir) ->
    ok = barrel_docdb:delete_db(mailboxes_read_model:db()),
    _ = file:del_dir_r(Dir),
    ok.

deposit(LetterId, At) ->
    ok = mailboxes_read_model:upsert_deposited(?ALICE, #{letter_id => LetterId, from_did => ?BOB,
                                                         subject => <<"hello">>, body => <<"body">>,
                                                         deposited_at => At}).

a_deposited_letter_is_listed_unread_and_found(_Dir) ->
    deposit(<<"l1">>, 1000),
    [?_assertMatch([#{<<"letter_id">> := <<"l1">>, <<"read">> := false}],
                   mailboxes_read_model:list_unarchived(?ALICE)),
     ?_assertMatch({ok, #{<<"from_did">> := ?BOB}}, mailboxes_read_model:find(?ALICE, <<"l1">>)),
     ?_assertEqual([], mailboxes_read_model:list_unarchived(?BOB))].

a_read_letter_is_listed_after_the_unread_ones(_Dir) ->
    deposit(<<"old">>, 1000),
    deposit(<<"new">>, 2000),
    deposit(<<"seen">>, 3000),
    ok = mailboxes_read_model:mark_read(?ALICE, <<"seen">>),
    ?_assertEqual([<<"new">>, <<"old">>, <<"seen">>],
                  [maps:get(<<"letter_id">>, L) || L <- mailboxes_read_model:list_unarchived(?ALICE)]).

an_archived_letter_is_found_but_not_listed(_Dir) ->
    deposit(<<"l1">>, 1000),
    ok = mailboxes_read_model:mark_archived(?ALICE, <<"l1">>),
    [?_assertEqual([], mailboxes_read_model:list_unarchived(?ALICE)),
     ?_assertMatch({ok, #{<<"archived">> := true}}, mailboxes_read_model:find(?ALICE, <<"l1">>))].

%% A restart opens the database that is already there.
reopening_an_existing_read_model_is_fine(Dir) ->
    ?_assertEqual(ok, mailboxes_read_model:open(Dir)).
