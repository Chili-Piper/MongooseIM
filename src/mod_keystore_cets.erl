-module(mod_keystore_cets).
-behaviour(mod_keystore_backend).

-export([init/2,
         init_ram_key/1,
         get_key/1]).

%% CETS callbacks
-export([handle_conflict/2]).

-ignore_xref([get_key/1, init/2, init_ram_key/1]).

-include("mod_keystore.hrl").
-include("mongoose_logger.hrl").

-define(TABLE, cets_keystore).

-spec init(mongooseim:host_type(), gen_mod:module_opts()) -> ok.
init(_HostType, _Opts) ->
    %% There is no logic to remove keys.
    cets:start(?TABLE, #{handle_conflict => fun ?MODULE:handle_conflict/2}),
    cets_discovery:add_table(mongoose_cets_discovery, ?TABLE),
    ok.

%% We need to choose one key consistently.
handle_conflict(Rec1, Rec2) ->
    max(Rec1, Rec2).

-spec init_ram_key(ProposedKey) -> Result when
      ProposedKey :: mod_keystore:key(),
      Result :: {ok, ActualKey} | {error, init_ram_key_failed},
      ActualKey :: mod_keystore:key().
init_ram_key(ProposedKey) ->
    init_ram_key(ProposedKey, 1, 3).

%% Inserts new key or returns already inserted.
-spec init_ram_key(Key, TriedTimes, Retries) -> Result when
      Result :: {ok, Key} | {error, init_ram_key_failed},
      Key :: mod_keystore:key(),
      TriedTimes :: non_neg_integer(),
      Retries :: non_neg_integer().
init_ram_key(#key{id = Id, key = Key}, _, 0) ->
    ?LOG_ERROR(#{what => init_ram_key_failed, id => Id, key => Key}),
    {error, init_ram_key_failed};
init_ram_key(ProposedKey = #key{id = Id, key = PropKey}, N, Retries) ->
    case cets:insert_new(?TABLE, {Id, PropKey}) of
        true ->
            {ok, ProposedKey};
        false ->
            case ets:lookup(?TABLE, Id) of
                [{Id, Key}] ->
                    %% Return already inserted key
                    {ok, #key{id = Id, key = Key}};
                [] ->
                    ?LOG_WARNING(#{what => init_ram_key_retry,
                                   id => Id, key => PropKey, tried_times => N}),
                    init_ram_key(ProposedKey, N + 1, Retries - 1)
            end
   end.

-spec get_key(Id :: mod_keystore:key_id()) -> mod_keystore:key_list().
get_key(Id) ->
    ets:lookup(?TABLE, Id).
