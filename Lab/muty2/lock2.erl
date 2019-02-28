-module(lock2).
-export([start/1]).

start(MyId) ->
    spawn(fun() -> init(MyId) end).

init(MyId) ->
    receive
        {peers, Nodes} ->
            open(Nodes,MyId);
        stop ->
            ok
    end.

open(Nodes,MyId) -> %Estado open
    receive
        {take, Master, Ref} ->
            Refs = requests(Nodes,MyId),
            wait(Nodes, Master, Refs, [], Ref, MyId);
        {request, From,  Ref, _} ->
            From ! {ok, Ref},
            open(Nodes,MyId);
        stop ->
            ok
    end.

requests(Nodes, MyId) ->
    lists:map(
      fun(P) -> 
        R = make_ref(), 
        P ! {request, self(), R, MyId}, 
        R 
      end, 
      Nodes).

wait(Nodes, Master, [], Waiting, TakeRef,MyId) ->
    Master ! {taken, TakeRef},
    held(Nodes, Waiting,MyId);
%si proces més prioritari tornar a enviar request a aquest    
wait(Nodes, Master, Refs, Waiting,TakeRef,MyId) ->
    receive
        {request, From,Ref,Id2} ->
        %{request, From, Ref} ->
            if  MyId < Id2 -> wait(Nodes, Master, Refs, [{From, Ref}|Waiting], TakeRef, MyId);
            true -> 
                R = make_ref(),
                From ! {ok,Ref},
                From ! {request,self(),R,MyId},
                wait(Nodes, Master, [R|Refs], Waiting, TakeRef, MyId)
            end;
        {ok, Ref} ->
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef, MyId);
        release ->
            ok(Waiting),            
            open(Nodes,MyId)
    end.

ok(Waiting) -> 
    lists:map(
      fun({F,R}) -> 
        F ! {ok, R} 
      end, 
      Waiting).

held(Nodes, Waiting, MyId) -> %estado held
    receive
        {request, From, Ref, _} ->
            held(Nodes, [{From, Ref}|Waiting],MyId);
        release ->
            ok(Waiting),
            open(Nodes,MyId)
    end.
 
