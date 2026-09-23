%%% @doc RESPONDER for the `mcl-mail/archive_letter' procedure.
%%%
%%% Archives a letter in the CALLER's own mailbox (see `mailbox_citizen').
%%% The letter stays in the record; it only stops being listed.
%%% @end
-module(archive_letter_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(archived(mailbox_citizen:caller(Payload), Payload), State).

archived({ok, CitizenDid}, Payload) ->
    commanded(archive_letter_v1:new(#{
        citizen_did => CitizenDid,
        letter_id => mcl_om_wire:field(letter_id, Payload)
    }));
archived({error, _} = Refused, _Payload) ->
    Refused.

commanded({ok, Cmd}) ->
    dispatched(archive_letter_v1:get_letter_id(Cmd), maybe_archive_letter:dispatch(Cmd));
commanded({error, _} = Refused) ->
    Refused.

dispatched(LetterId, {ok, _Version, _Events}) -> {ok, LetterId};
dispatched(_LetterId, {error, _} = Refused) -> Refused.

replied({ok, LetterId}, State) -> {reply, #{letter_id => {text, LetterId}}, State};
replied({error, Reason}, State) -> {error, Reason, State}.
