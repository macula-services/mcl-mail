%% @doc OTP application entry.
%%
%% Opens this service's own reckon-db store and its evoq subscription
%% (mcl_mail_store, from mcl_mail_service:event_store/0), THEN lets
%% mcl_om:boot/1 wire the mesh, the realm identity and health, advertise the
%% procedures and start the service. mcl_om opens no store (0.35, mcl-om#10).
%% The letter read model is project_mailboxes' own, opened when that app starts.
-module(mcl_mail_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    ok = mcl_mail_store:open(mcl_mail_service:event_store()),
    mcl_om:boot(mcl_mail_service).

stop(_State) -> ok.
