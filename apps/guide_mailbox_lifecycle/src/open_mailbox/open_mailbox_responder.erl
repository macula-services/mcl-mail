%%% @doc RESPONDER for the `mcl-mail/open_mailbox' procedure.
%%%
%%% Opens the CALLER's own mailbox to incoming mail: the citizen is whoever
%%% signed the CALL (see `mailbox_citizen'), so nobody can open a mailbox on
%%% somebody else's behalf.
%%% @end
-module(open_mailbox_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(opened(mailbox_citizen:caller(Payload)), State).

opened({ok, CitizenDid}) ->
    {ok, Cmd} = open_mailbox_v1:new(#{citizen_did => CitizenDid}),
    maybe_open_mailbox:dispatch(Cmd);
opened({error, _} = Refused) ->
    Refused.

replied({ok, _Version, _Events}, State) -> {reply, #{}, State};
replied({error, Reason}, State) -> {error, Reason, State}.
