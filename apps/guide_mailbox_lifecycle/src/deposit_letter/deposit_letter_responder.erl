%%% @doc RESPONDER for the `mcl-mail/deposit_letter' procedure.
%%%
%%% Write-only: a deposit discloses nothing about the recipient's mailbox,
%%% so anyone may leave a letter in a mailbox that is open. The SENDER is
%%% the CALL's caller, verified by macula (see `mailbox_citizen'), never a
%%% field of the payload, so a letter's `from_did' is who actually sent it.
%%% The recipient is named by `to_citizen_did', hex text.
%%%
%%% Replies with the new letter's id.
%%% @end
-module(deposit_letter_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(deposited(mailbox_citizen:caller(Payload), recipient(Payload), Payload), State).

recipient(Payload) ->
    named(mailbox_citizen:did(mcl_om_wire:field(to_citizen_did, Payload))).

named({ok, _Did} = Named) -> Named;
named({error, invalid_did}) -> {error, invalid_to_citizen_did}.

deposited({ok, From}, {ok, To}, Payload) ->
    {ok, Cmd} = deposit_letter_v1:new(#{
        to_citizen_did => To,
        from_did => From,
        subject => mcl_om_wire:field(subject, Payload, <<"">>),
        body => mcl_om_wire:field(body, Payload, <<"">>),
        reply_letter_id => mcl_om_wire:field(reply_letter_id, Payload)
    }),
    with_letter_id(deposit_letter_v1:get_letter_id(Cmd), maybe_deposit_letter:dispatch(Cmd));
deposited({error, _} = Refused, _To, _Payload) ->
    Refused;
deposited(_From, {error, _} = Refused, _Payload) ->
    Refused.

with_letter_id(LetterId, {ok, _Version, _Events}) -> {ok, LetterId};
with_letter_id(_LetterId, {error, _} = Refused) -> Refused.

replied({ok, LetterId}, State) -> {reply, #{letter_id => {text, LetterId}}, State};
replied({error, Reason}, State) -> {error, Reason, State}.
