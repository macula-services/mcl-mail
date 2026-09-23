%%% @doc RESPONDER for the `mcl-mail/initiate_mailbox' procedure.
%%%
%%% Initiates the CALLER's own mailbox: the citizen is whoever signed the
%%% CALL (see `mailbox_citizen'), so nobody can bring a mailbox into being
%%% for somebody else.
%%% @end
-module(initiate_mailbox_responder).
-behaviour(macula_response).

-export([init/1, handle_request/2]).

init(_Args) -> {ok, []}.

-spec handle_request(map(), term()) -> {reply, map(), term()} | {error, atom(), term()}.
handle_request(Payload, State) ->
    replied(initiated(mailbox_citizen:caller(Payload)), State).

initiated({ok, CitizenDid}) ->
    {ok, Cmd} = initiate_mailbox_v1:new(#{citizen_did => CitizenDid}),
    maybe_initiate_mailbox:dispatch(Cmd);
initiated({error, _} = Refused) ->
    Refused.

replied({ok, _Version, _Events}, State) -> {reply, #{}, State};
replied({error, Reason}, State) -> {error, Reason, State}.
