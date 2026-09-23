%%% @doc RESPONDER for the `mcl-mail/get_mailbox' procedure.
%%%
%%% Lists the CALLER's own unarchived letters, unread first (see
%%% `mailbox_citizen' for why the caller is the citizen). A mailbox is one
%%% citizen's private mail, so nothing in the payload can name another.
%%%
%%% Fetching marks every returned letter read, collapsing two round trips
%%% into one. Letters come back with the read flag AS FETCHED, so a caller
%%% can tell what arrived since last time, and are marked read afterwards.
%%% @end
-module(get_mailbox_by_citizen_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(mailbox_citizen:caller(Payload), State).

replied({ok, CitizenDid}, State) ->
    Letters = mailboxes_read_model:list_unarchived(CitizenDid),
    lists:foreach(fun(Letter) -> mark_fetched_letter_read:mark(CitizenDid, Letter) end, Letters),
    {reply, #{letters => lists:map(fun mailboxes_read_model:to_wire/1, Letters)}, State};
replied({error, Reason}, State) ->
    {error, Reason, State}.
