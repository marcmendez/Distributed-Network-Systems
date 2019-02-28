-module(groupy).
-export([start/2, stop/0]).

% We use the name of the module (i.e. gms3) as the parameter Module to the start procedure. Sleep stands for up to how many milliseconds the workers should wait until the next message is sent.

start(Module, Sleep) ->
    P = worker:start("P1", Module, Sleep),
    register(a, P), 
    %register(b, worker:start("P2", Module, P, Sleep)),
    %register(c, worker:start("P3", Module, P, Sleep)),
    %register(d, worker:start("P4", Module, P, Sleep)),
    %register(e, worker:start("P5", Module, P, Sleep)).
    spawn('p2@127.0.0.1', fun() -> register(b, worker:start("P2", Module, P, Sleep))
			end),
    spawn('p3@127.0.0.1', fun() -> register(c, worker:start("P3", Module, P, Sleep))
			end),
    spawn('p4@127.0.0.1', fun() -> register(d, worker:start("P4", Module, P, Sleep))
			end),
    spawn('p5@127.0.0.1', fun() -> register(e, worker:start("P5", Module, P, Sleep))
			end).

stop() ->
    stop(a),
    {b,'p2@127.0.0.1'} ! stop,
    {c,'p3@127.0.0.1'} ! stop,
    {d,'p4@127.0.0.1'} ! stop,
    {e,'p5@127.0.0.1'} ! stop.
    %stop({b,'p2@127.0.0.1'}),
    %stop({c,'p3@127.0.0.1'}),
    %stop({d,'p4@127.0.0.1'}),
    %stop({e,'p5@127.0.0.1'}).
    
stop(Name) ->
    case whereis(Name) of
        undefined ->
            ok;
        Pid ->
            Pid ! stop        
    end.
