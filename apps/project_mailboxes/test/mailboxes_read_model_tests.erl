%%% @doc A stored letter, as it goes out on the wire.
%%%
%%% Text goes out `{text, Bin}', a CBOR text string: a bare binary is a CBOR
%%% byte string, and a non-BEAM client receives it as bytes. A DID goes out
%%% as hex text, the form a client names a recipient in. Flags are 0/1,
%%% never booleans.
-module(mailboxes_read_model_tests).

-include_lib("eunit/include/eunit.hrl").

-define(BOB, <<16#b0:256>>).

stored(Extra) ->
    maps:merge(#{<<"letter_id">> => <<"l1">>, <<"from_did">> => ?BOB,
                 <<"subject">> => <<"hello">>, <<"body">> => <<"can you build X?">>,
                 <<"deposited_at">> => 1000, <<"read">> => false, <<"replied">> => true,
                 <<"archived">> => false}, Extra).

a_letter_goes_out_as_text_hex_and_bits_test() ->
    ?assertEqual(#{letter_id => {text, <<"l1">>},
                   from_did => {text, binary:encode_hex(?BOB, lowercase)},
                   subject => {text, <<"hello">>},
                   body => {text, <<"can you build X?">>},
                   deposited_at => 1000,
                   read => 0, replied => 1, archived => 0},
                 mailboxes_read_model:to_wire(stored(#{}))).

a_reply_names_the_letter_it_answers_test() ->
    ?assertEqual({text, <<"l0">>},
                 maps:get(reply_letter_id,
                          mailboxes_read_model:to_wire(stored(#{<<"reply_letter_id">> => <<"l0">>})))).
