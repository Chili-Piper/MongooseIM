-module(mongoose_custom_log_filter).
-export([drop_by_regex_filter/2]).

-ignore_xref([drop_by_regex_filter/2]).

-include("mongoose.hrl").

-define(DROP_BY_LOG_FILTER_PATTERN, "DROP_BY_LOG_FILTER_PATTERN").

%% @doc
%% Filter function that reads DROP_BY_LOG_FILTER_PATTERN environment variable
%% and excludes log entries matching the regex pattern.
-spec drop_by_regex_filter(logger:log_event(), term()) -> logger:filter_return().
drop_by_regex_filter(Event = #{msg := Msg}, _Config) ->
    try
        Pattern = ensure_regex_compiled(),
        case match_msg(Msg, Pattern) of
            true -> stop;
            false -> Event
        end
    catch
        Class:Reason:Stacktrace ->
            logger:warning("drop_by_regex_filter crash: ~p:~p\nStacktrace: ~p", [Class, Reason, Stacktrace]),
            Event
    end;
drop_by_regex_filter(Event, _Config) ->
    Event.

%% Compile and cache regex using persistent_term for better reliability
ensure_regex_compiled() ->
    case persistent_term:get(?MODULE, undefined) of
        undefined ->
            case os:getenv(?DROP_BY_LOG_FILTER_PATTERN) of
                false ->
                    persistent_term:put(?MODULE, undefined),
                    undefined;
                RegexStr ->
                    case re:compile(RegexStr, [unicode, caseless]) of
                        {ok, Re} ->
                            persistent_term:put(?MODULE, Re),
                            Re;
                        {error, _} ->
                            persistent_term:put(?MODULE, undefined),
                            undefined
                    end
            end;
        Regex -> Regex
    end.

%% Convert logger message to string and match
match_msg({FormatFun, Args}, Re) when is_function(FormatFun, 2), is_list(Args), Re =/= undefined ->
    try
        case Args of
            [FormatStr, FormatArgs] when is_list(FormatStr), is_list(FormatArgs) ->
                MsgStr = lists:flatten(io_lib:format(FormatStr, FormatArgs)),
                re:run(MsgStr, Re) =/= nomatch;
            [FormatStr] when is_list(FormatStr) ->
                MsgStr = lists:flatten(FormatStr),
                re:run(MsgStr, Re) =/= nomatch;
            _ ->
                MsgStr = lists:flatten(io_lib:format("~p", [Args])),
                re:run(MsgStr, Re) =/= nomatch
        end
    catch _:_ -> false end;

match_msg({string, S}, Re) when is_list(S), Re =/= undefined ->
    try
        re:run(S, Re) =/= nomatch
    catch _:_ -> false end;

match_msg({report, R}, Re) when Re =/= undefined ->
    try
        MsgStr = lists:flatten(io_lib:format("~p", [R])),
        re:run(MsgStr, Re) =/= nomatch
    catch _:_ -> false end;

match_msg({report, R, Meta}, Re) when Re =/= undefined ->
    try
        MsgStr = lists:flatten(io_lib:format("~p ~p", [R, Meta])),
        re:run(MsgStr, Re) =/= nomatch
    catch _:_ -> false end;

match_msg(Msg, Re) when Re =/= undefined ->
    try
        MsgStr = lists:flatten(io_lib:format("~p", [Msg])),
        re:run(MsgStr, Re) =/= nomatch
    catch _:_ -> false end;

match_msg(_, _) -> false.
