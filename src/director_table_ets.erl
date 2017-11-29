%%% ------------------------------------------------------------------------------------------------
%%% Director is available for use under the following license, commonly known as the 3-clause (or
%%% "modified") BSD license:
%%%
%%% Copyright (c) 2017-2018, Pouriya Jahanbakhsh
%%% (pouriya.jahanbakhsh@gmail.com)
%%% All rights reserved.
%%%
%%% Redistribution and use in source and binary forms, with or without modification, are permitted
%%% provided that the following conditions are met:
%%%
%%% 1. Redistributions of source code must retain the above copyright notice, this list of
%%%    conditions and the following disclaimer.
%%%
%%% 2. Redistributions in binary form must reproduce the above copyright notice, this list of
%%%    conditions and the following disclaimer in the documentation and/or other materials provided
%%%    with the distribution.
%%%
%%% 3. Neither the name of the copyright holder nor the names of its contributors may be used to
%%%    endorse or promote products derived from this software without specific prior written
%%%    permission.
%%%
%%% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
%%% IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
%%% FITNESS FOR A  PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
%%% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
%%% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
%%% SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
%%% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
%%% OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
%%% POSSIBILITY OF SUCH DAMAGE.
%%% ------------------------------------------------------------------------------------------------
%% @author   Pouriya Jahanbakhsh <pouriya.jahanbakhsh@gmail.com>
%% @version  17.10.25
%% @hidden
%% -------------------------------------------------------------------------------------------------


-module(director_table_ets).
-author("pouriya.jahanbakhsh@gmail.com").
-behaviour(director_table).


%% -------------------------------------------------------------------------------------------------
%% Exports:

%% API:
-export([count_children/1
        ,which_children/1
        ,get_childspec/2
        ,get_pid/2
        ,get_pids/1
        ,get_plan/2
        ,get_restart_count/2
        ,options/0]).

%% director's API:
-export([create/1
        ,insert/2
        ,delete/2
        ,lookup_id/2
        ,lookup_pid/2
        ,lookup_appended/1
        ,count/1
        ,delete_table/1
        ,tab2list/1
        ,handle_message/2
        ,change_parent/2]).

%% -------------------------------------------------------------------------------------------------
%% Records & Macros & Includes:

-define(TABLE_OPTIONS, [public, named_table, set, {keypos, 2}]).

%% Dependencies:
%%  #?CHILD{}
-include("internal/director_child.hrl").

-define(is_valid_type(Type), (Type =:= set orelse Type =:= ordered_set)).

%% -------------------------------------------------------------------------------------------------
%% API:

count_children(Tab) ->
    director_table:count_children(?MODULE, Tab).


which_children(Tab) ->
    director_table:which_children(?MODULE, Tab).


get_childspec(Tab, Id) ->
    director_table:get_childspec(?MODULE, Tab, Id).


get_pid(Tab, Id) ->
    director_table:get_pid(?MODULE, Tab, Id).


get_pids(Tab) ->
    director_table:get_pids(?MODULE, Tab).


get_plan(Tab, Id) ->
    director_table:get_plan(?MODULE, Tab, Id).


get_restart_count(Tab, Id) ->
    director_table:get_restart_count(?MODULE, Tab, Id).


options() ->
    ?TABLE_OPTIONS.

%% -------------------------------------------------------------------------------------------------
%% Director's API functions:

create({value, TabName}) ->
    case is_table(TabName) of
        true ->
            Self = erlang:self(),
            case {ets:info(TabName, protection)
                 ,ets:info(TabName, owner)
                 ,ets:info(TabName, type)
                 ,ets:info(TabName, keypos)} of
                {public, _, Type, 2} when ?is_valid_type(Type) ->
                    {ok, TabName};
                {public, _, Type, Keypos} when ?is_valid_type(Type) ->
                    {hard_error, {table_keypos, [{keypos, Keypos}]}};
                {public, _, Type, _} ->
                    {hard_error, {table_type, [{type, Type}]}};
                {_, Self, Type, 2} when ?is_valid_type(Type) ->
                    {ok, TabName};
                {_, Self, Type, KeyPos} when ?is_valid_type(Type) ->
                    {hard_error, {table_keypos, [{keypos, KeyPos}]}};
                {_, Self, Type, _} ->
                    {hard_error, {table_type, [{type, Type}]}};
                {Protection, Pid, _Type, _Keypos} ->
                    {hard_error, {table_protection_and_owner, [{protection, Protection}
                                                              ,{owner, Pid}]}}
            end;
        false ->
            try
                {ok, ets:new(TabName, ?TABLE_OPTIONS)}
            catch
                _:Reason ->
                    {hard_error, {table_create, [{reason, Reason}]}}
            end
    end.


delete_table(Tab) ->
    try ets:delete(Tab) of
        _ ->
            ok
    catch
        _:_ ->
            table_error(Tab)
    end.


lookup_id(Tab, Id) ->
    try ets:lookup(Tab, Id) of
        [Child] ->
            {ok, Child};
        [] ->
            {soft_error, not_found}
    catch
        _:_ ->
            table_error(Tab)
    end.


count(Tab) ->
    case ets:info(Tab, size) of
        undefined ->
            {hard_error, {table_existence, []}};
        Size ->
            {ok, Size}
    end.


lookup_pid(Tab, Pid) ->
    try ets:match_object(Tab, #?CHILD{pid = Pid, _ = '_'}) of
        [Child] ->
            {ok, Child};
        [] ->
            {soft_error, not_found}
    catch
        _:_ ->
            table_error(Tab)
    end.


lookup_appended(Tab) ->
    try
        {ok, ets:match_object(Tab, #?CHILD{append = true, _ = '_'})}
    catch
        _:_ ->
            table_error(Tab)
    end.


insert(Tab, Child) ->
    try
        _ = ets:insert(Tab, Child),
        {ok, Tab}
    catch
        _:_ ->
            table_error(Tab)
    end.


delete(Tab, #?CHILD{id=Id}) ->
    try
        _ = ets:delete(Tab, Id),
        {ok, Tab}
    catch
        _:_ ->
            table_error(Tab)
    end.


tab2list(Tab) ->
    try
        {ok, ets:tab2list(Tab)}
    catch
        _:_ ->
            table_error(Tab)
    end.


handle_message(Tab, _) ->
    {soft_error, Tab, unknown}.


change_parent(Tab, #?CHILD{id = Id}=Child) ->
    try ets:lookup(Tab, Id) of
        [#?CHILD{supervisor = Pid}] when erlang:self() =/= Pid andalso Pid =/= undefined ->
            {soft_error, not_parent};
        _ ->
            _ = ets:insert(Tab, Child),
            {ok, Tab}
    catch
        _:_ ->
            table_error(Tab)
    end.

%% -------------------------------------------------------------------------------------------------
%% Internal functions:

table_error(Tab) ->
    case is_table(Tab) of
        true ->
            {hard_error, {table_protection_and_owner, [{protection, ets:info(Tab, protection)}
                                                      ,{owner, ets:info(Tab, owner)}]}};
        false ->
            {hard_error, {table_existence, []}}
    end.


is_table(Tab) ->
    lists:member(Tab, ets:all()).