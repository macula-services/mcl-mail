%%% @doc RESPONDER for the `mcl-mail/reply_to_letter' procedure.
%%%
%%% Replies out of the CALLER's own mailbox (see `mailbox_citizen'): marks
%%% the letter answered there, then deposits the reply into the mailbox of
%%% whoever sent the original, read from the letter itself and never from
%%% the payload.
%%%
%%% If the answer is marked but the reply cannot be delivered (the original
%%% sender has since closed their mailbox), the mark stands and the call says
%%% `replied_but_not_delivered', so the caller knows the other side has
%%% nothing.
%%% @end
-module(reply_to_letter_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

-include_lib("kernel/include/logger.hrl").

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(answered(mailbox_citizen:caller(Payload), Payload), State).

answered({ok, CitizenDid}, Payload) ->
    commanded(reply_to_letter_v1:new(#{
        citizen_did => CitizenDid,
        letter_id => mcl_om_wire:field(letter_id, Payload),
        subject => mcl_om_wire:field(subject, Payload, <<"">>),
        body => mcl_om_wire:field(body, Payload, <<"">>)
    }));
answered({error, _} = Refused, _Payload) ->
    Refused.

commanded({ok, Cmd}) ->
    dispatched(reply_to_letter_v1:get_letter_id(Cmd), maybe_reply_to_letter:dispatch(Cmd));
commanded({error, _} = Refused) ->
    Refused.

dispatched(LetterId, {ok, _Version, _Events}) ->
    {ok, LetterId};
dispatched(LetterId, {error, {replied_but_delivery_failed, Why}}) ->
    ?LOG_WARNING("mcl-mail: letter ~s answered, reply not delivered: ~p", [LetterId, Why]),
    {error, replied_but_not_delivered};
dispatched(_LetterId, {error, _} = Refused) ->
    Refused.

replied({ok, LetterId}, State) -> {reply, #{letter_id => {text, LetterId}}, State};
replied({error, Reason}, State) -> {error, Reason, State}.
