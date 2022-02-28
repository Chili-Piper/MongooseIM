-module(mongoose_graphql_stanza_admin_query).

-export([execute/4]).

-ignore_xref([execute/4]).

-include("../mongoose_graphql_types.hrl").
-include("mongoose_logger.hrl").

-type result() :: {ok, map()} | {error, term()}.

-spec execute(graphql:endpoint_context(), graphql:ast(), binary(), map()) ->
        result().
execute(_Ctx, _Obj, <<"getLastMessages">>, Opts) ->
    get_last_messages(Opts).

get_last_messages(#{<<"caller">> := Caller, <<"limit">> := Limit,
                    <<"with">> := With, <<"before">> := Before})
        when is_integer(Limit) ->
    case mongoose_graphql_helper:check_user(Caller) of
        {ok, _HostType} ->
            mongoose_stanza_helper:get_last_messages(Caller, Limit, With, Before);
        Error ->
            Error
    end.
