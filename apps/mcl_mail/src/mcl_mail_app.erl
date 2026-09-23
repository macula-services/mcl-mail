%% @doc OTP application entry.
%%
%% mcl_om:boot/1 wires the mesh, the realm identity and health, opens the
%% reckon-db store (store_id/0 + data_dir/0) with its evoq subscription and the
%% barrel_docdb read model (read_model_id/0), advertises the procedures, then
%% starts this service.
-module(mcl_mail_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) -> mcl_om:boot(mcl_mail_service).

stop(_State) -> ok.
