%% @doc OTP application entry for the PRJ department.
%%
%% Opens the letter read model BEFORE the projection starts. mcl_om replays
%% the store into the projection at boot, and a replayed letter written into a
%% database nobody has opened yet would crash the worker, so the department
%% that writes the model opens it, first.
-module(project_mailboxes_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    ok = mailboxes_read_model:open(data_dir()),
    project_mailboxes_sup:start_link().

%% config/sys.config.src sets it from MCL_DATA_DIR, the service's data volume.
data_dir() -> application:get_env(project_mailboxes, data_dir, "/tmp/mcl_mail").

stop(_State) -> ok.
