%%% @doc RESPONDER for the `mcl-mail/get_letter' procedure.
%%%
%%% Fetches one letter from the CALLER's own mailbox (see `mailbox_citizen'),
%%% and marks it read, the same implicit-read rule as `get_mailbox'. A letter
%%% id that is not in the caller's mailbox is `not_found', whoever else may
%%% hold a letter by that id.
%%% @end
-module(get_letter_by_id_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(fetched(mailbox_citizen:caller(Payload), mcl_om_wire:field(letter_id, Payload)),
            State).

fetched({ok, CitizenDid}, LetterId) when is_binary(LetterId) ->
    found(mailboxes_read_model:find(CitizenDid, LetterId), CitizenDid);
fetched({ok, _CitizenDid}, _Missing) ->
    {error, missing_letter_id};
fetched({error, _} = Refused, _LetterId) ->
    Refused.

found({ok, Letter}, CitizenDid) ->
    mark_fetched_letter_read:mark(CitizenDid, Letter),
    {ok, Letter};
found({error, not_found} = NotFound, _CitizenDid) ->
    NotFound.

replied({ok, Letter}, State) -> {reply, #{letter => mailboxes_read_model:to_wire(Letter)}, State};
replied({error, Reason}, State) -> {error, Reason, State}.
