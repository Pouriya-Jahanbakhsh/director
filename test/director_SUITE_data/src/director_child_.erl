-module(director_child_).
-export([start_link/1
        ,start_link/2
        ,init/1
        ,handle_info/2
        ,terminate/2
        ,code_change/3]).






start_link(Arg) ->
    gen_server:start_link(?MODULE, Arg, []).


start_link(Name, Arg) ->
    gen_server:start_link(Name, ?MODULE, Arg, []).



init(Arg) ->
    Arg().


handle_info(_, St) ->
    {noreply, St}.


terminate(_Reason, _State) ->
    ok.




code_change(_, State, _) ->
    {ok, State}.