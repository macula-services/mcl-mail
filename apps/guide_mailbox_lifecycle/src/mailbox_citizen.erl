%%% @doc Who a CALL acts as, and how a citizen's DID crosses the wire.
%%%
%%% A citizen's DID is a macula node id: 32 bytes, the SHA-256 of the
%%% identity key it names. macula 12 puts `caller' on every inbound CALL's
%%% payload, the node id of the key that signed the request. Every station on
%%% the path verifies that signature against it, the provider verifies it
%%% again before any handler runs, and `macula_station_link:with_caller/2'
%%% writes it over any `caller' the payload itself sent. So `caller' IS
%%% proof of the private key, and every mailbox procedure acts as it: a
%%% citizen reads, replies from and archives in their own mailbox, and the
%%% sender of a deposited letter is whoever signed the deposit.
%%%
%%% That replaces the 10.x ownership proof, where a DID was a bare Ed25519
%%% key and the caller signed `{citizen_did, timestamp, procedure}' by hand.
%%% It needed binding to the CALL's caller to stop a replay from another
%%% identity, and once bound, the caller alone proves everything the proof
%%% did.
%%%
%%% A DID a client NAMES, a letter's recipient, travels as hex text, and
%%% arrives `{text, Bin}'-tagged whenever the receiving VM has no atom for it
%%% (`mcl_om_wire:field/2' unwraps that). Raw bytes are accepted too, the form
%%% a BEAM client sending a CBOR byte string delivers.
%%% @end
-module(mailbox_citizen).

-export([caller/1, did/1, to_wire/1]).

%% @doc The node id the CALL was signed by.
-spec caller(map()) -> {ok, <<_:256>>} | {error, no_caller}.
caller(Payload) -> node_id(mcl_om_wire:caller(Payload)).

node_id(<<_:256>> = NodeId) -> {ok, NodeId};
node_id(_Missing) -> {error, no_caller}.

%% @doc A DID as a client sent it: 64 hex characters, or the 32 raw bytes.
-spec did(term()) -> {ok, <<_:256>>} | {error, invalid_did}.
did(Value) -> decoded(mcl_om_wire:unwrap(Value)).

decoded(<<_:256>> = Raw) -> {ok, Raw};
decoded(Hex) when is_binary(Hex), byte_size(Hex) =:= 64 ->
    try {ok, binary:decode_hex(Hex)} catch error:badarg -> {error, invalid_did} end;
decoded(_Other) -> {error, invalid_did}.

%% @doc A DID going out: hex text, the same form a client names one in.
-spec to_wire(<<_:256>>) -> {text, binary()}.
to_wire(<<_:256>> = Did) -> {text, binary:encode_hex(Did, lowercase)}.
