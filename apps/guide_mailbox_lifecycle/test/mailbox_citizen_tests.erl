%%% @doc Who a CALL acts as, and how a citizen's DID crosses the wire.
%%%
%%% macula 12 puts `caller' on every inbound CALL's payload: the node id of
%%% the identity key that signed the request, verified by every station on
%%% the path and again by this provider, and written over any `caller' the
%%% payload itself sent. A citizen's DID is that same 32-byte node id.
-module(mailbox_citizen_tests).

-include_lib("eunit/include/eunit.hrl").

-define(ALICE, <<16#a1:256>>).

caller_is_the_wire_authenticated_node_id_test() ->
    ?assertEqual({ok, ?ALICE}, mailbox_citizen:caller(#{caller => ?ALICE})).

%% Only a test or a misuse reaches a handler without one: every CALL macula
%% delivers carries it. Refused loudly rather than acting as nobody.
a_payload_without_a_caller_is_refused_test() ->
    ?assertEqual({error, no_caller}, mailbox_citizen:caller(#{})).

a_caller_that_is_not_a_node_id_is_refused_test() ->
    ?assertEqual({error, no_caller}, mailbox_citizen:caller(#{caller => <<"alice">>})).

%% A DID a client names (a letter's recipient) travels as hex TEXT, and
%% arrives `{text, Bin}'-tagged whenever the receiving VM has no atom for it.
a_did_arrives_as_hex_text_test() ->
    Hex = binary:encode_hex(?ALICE, lowercase),
    ?assertEqual({ok, ?ALICE}, mailbox_citizen:did({text, Hex})),
    ?assertEqual({ok, ?ALICE}, mailbox_citizen:did(Hex)).

uppercase_hex_is_the_same_did_test() ->
    ?assertEqual({ok, ?ALICE}, mailbox_citizen:did(binary:encode_hex(?ALICE, uppercase))).

a_did_that_is_not_32_bytes_of_hex_is_refused_test() ->
    ?assertEqual({error, invalid_did}, mailbox_citizen:did(undefined)),
    ?assertEqual({error, invalid_did}, mailbox_citizen:did({text, <<"did:macula:alice">>})),
    ?assertEqual({error, invalid_did}, mailbox_citizen:did(binary:copy(<<"zz">>, 32))).

%% Raw bytes are accepted too: they are how a BEAM client that sends a CBOR
%% byte string delivers the same 32 bytes.
raw_bytes_are_the_same_did_test() ->
    ?assertEqual({ok, ?ALICE}, mailbox_citizen:did(?ALICE)).

%% Going out, a DID is hex TEXT, so a non-BEAM client reads a string it can
%% hand straight back as a recipient.
a_did_goes_out_as_hex_text_test() ->
    ?assertEqual({text, binary:encode_hex(?ALICE, lowercase)}, mailbox_citizen:to_wire(?ALICE)).
