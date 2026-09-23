%% @doc OTP application entry.
%%
%% mcl_om:boot/1 wires the mesh, the realm identity and health, opens the
%% reckon-db store (store_id/0 + data_dir/0) with its evoq subscription,
%% advertises the procedures, then starts this service. The letter read model
%% is project_mailboxes' own, opened when that app starts.
-module(mcl_mail_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> mcl_om:boot(mcl_mail_service).

stop(_State) -> ok.
