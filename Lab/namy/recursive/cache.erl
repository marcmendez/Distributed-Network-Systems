-module(cache).
-export([lookup/2, add/4, remove/2, new/0]).

lookup(Name, Cache) ->
	case lists:keyfind(Name,1,Cache) of
		false -> 
			unknown;
		{Name, Reply, TTL} ->
			Now = erlang:monotonic_time(),
			Expire = erlang:convert_time_unit(Now, native, second),
			case Expire > TTL of
				true ->
					invalid;
				false ->
					Reply
			end
	end.		
    
add(Name, Expire, Reply, Cache) ->
lists:keystore(Name,1,Cache, {Name, Reply , Expire}).

remove(Name, Cache) ->
lists:keydelete(Name, 1, Cache).

new() ->
[].

