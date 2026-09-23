%%% @doc Marks a fetched letter read, for both QRY desks.
%%%
%%% A read is a fact about the mailbox, so it goes through the CMD desk as
%%% `mark_letter_read_v1' rather than being written into the read model
%%% here; the projection brings the read model up to date. Best effort: a
%%% letter the citizen has just archived, or a mailbox closed in between,
%%% refuses the mark, and the fetch that caused it still answers.
%%% @end
-module(mark_fetched_letter_read).

-export([mark/2]).

-include_lib("kernel/include/logger.hrl").

-spec mark(<<_:256>>, map()) -> ok.
mark(CitizenDid, #{<<"read">> := false, <<"letter_id">> := LetterId}) ->
    {ok, Cmd} = mark_letter_read_v1:new(#{citizen_did => CitizenDid, letter_id => LetterId}),
    marked(LetterId, maybe_mark_letter_read:dispatch(Cmd));
mark(_CitizenDid, _AlreadyRead) ->
    ok.

marked(_LetterId, {ok, _Version, _Events}) -> ok;
marked(LetterId, {error, Why}) ->
    ?LOG_INFO("mcl-mail: letter ~s fetched, not marked read: ~p", [LetterId, Why]).
