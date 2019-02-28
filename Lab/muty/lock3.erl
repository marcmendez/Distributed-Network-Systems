-module(lock3).
-export([start/1]).

start(MyId) ->
    spawn(fun() -> init(MyId) end).

init(MyId) ->
    receive
        {peers, Nodes} ->
            MyClk = 0,
            open(Nodes,MyId, MyClk);
        stop ->
            ok
    end.

open(Nodes,MyId, MyClk) -> %Estado open
    receive
        {take, Master, Ref} ->
            NewClk = MyClk + 1,
            Refs = requests(Nodes,MyId, NewClk),
            wait(Nodes, Master, Refs, [], Ref, MyId, NewClk, NewClk);
        {request, From,  Ref, _, YourClk} ->
            NewClk = max(YourClk, MyClk),
            From ! {ok, Ref},
            open(Nodes,MyId, NewClk);
        stop ->
            ok
    end.

requests(Nodes, MyId, MyClk) ->
    lists:map(
      fun(P) -> 
        R = make_ref(), 
        P ! {request, self(), R, MyId, MyClk}, 
        R 
      end, 
      Nodes).

wait(Nodes, Master, [], Waiting, TakeRef,MyId, MyClk, _) ->
    Master ! {taken, TakeRef},
    held(Nodes, Waiting,MyId, MyClk);
%si proces més prioritari tornar a enviar request a aquest    
wait(Nodes, Master, Refs, Waiting,TakeRef,MyId, MyClk, ClkReq) ->
    receive
        {request, From,Ref,Id2, YourClk} ->
            NewClk = max(YourClk, MyClk),
            if  ClkReq < YourClk ->  wait(Nodes, Master, Refs, [{From, Ref}|Waiting], TakeRef, MyId,NewClk,ClkReq);
                YourClk < ClkReq ->   
                        R = make_ref(),
                        From ! {ok,Ref},
                        From ! {request,self(),R,MyId,ClkReq},
                        wait(Nodes, Master, [R|Refs], Waiting, TakeRef, MyId,NewClk, ClkReq);
                true -> 
                    if MyId < Id2 -> wait(Nodes, Master, Refs, [{From, Ref}|Waiting], TakeRef, MyId, NewClk, ClkReq);
                    true -> 
                        R = make_ref(),
                        From ! {ok,Ref},
                        From ! {request,self(),R,MyId, ClkReq},
                        wait(Nodes, Master, [R|Refs], Waiting, TakeRef, MyId, NewClk, ClkReq)
                    end
            end;
        {ok, Ref} ->
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef, MyId, MyClk, ClkReq);
        release ->
            ok(Waiting),            
            open(Nodes,MyId, MyClk)
    end.

ok(Waiting) -> 
    lists:map(
      fun({From,Ref}) -> 
        From ! {ok, Ref} 
      end, 
      Waiting).

held(Nodes, Waiting, MyId, MyClk) -> %estado held
    receive
        {request, From, Ref, _ , YourClk} ->
            NewClk = max(YourClk, MyClk),
            held(Nodes, [{From, Ref}|Waiting],MyId, NewClk);
        release ->
            ok(Waiting),
            open(Nodes,MyId, MyClk)
    end.
 
