-module(director_callback).
-export([init/1]).




init(InitArg) ->
    InitArg().
