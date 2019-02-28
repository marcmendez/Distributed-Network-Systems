-module(lock3).
-export([start/1]).

start(MyId) ->
    spawn(fun() -> init(MyId) end).

init(MyId) ->
    receive
        {peers, Nodes} ->
            MyClk=0,
            open(Nodes,MyId,MyClk);
        stop ->
            ok
    end.

open(Nodes,MyId,MyClk) -> %Estado open
    receive
        {take, Master, Ref} ->
            NewClk = MyClk + 1,   
            Refs = requests(Nodes,MyId,NewClk),
            wait(Nodes, Master, Refs, [], Ref, MyId,NewClk,NewClk);
        {request, From,  Ref, _, _} ->
            From ! {ok, Ref},
            open(Nodes,MyId,MyClk);
        stop ->
            ok
    end.

requests(Nodes, MyId,MyClk) ->
    lists:map(
      fun(P) -> 
        R = make_ref(),
        P ! {request, self(), R, MyId,MyClk},
        R 
      end, 
      Nodes).

wait(Nodes, Master, [], Waiting, TakeRef,MyId,MyClk, ClkReq) ->
    Master ! {taken, TakeRef},
    held(Nodes, Waiting,MyId,MyClk);
wait(Nodes, Master, Refs, Waiting,TakeRef,MyId,MyClk,ClkReq) ->
    receive
        {request, From,Ref,Id2,YourClk} ->
        	NewClk = max(YourClk, MyClk),      
            if ClkReq < YourClk -> wait(Nodes, Master, Refs, [{From, Ref}|Waiting], TakeRef, MyId,NewClk,ClkReq);
           	if ClkReq > YourClk -> 
           		R = make_ref(),
                From ! {ok,Ref},
                From ! {request,self(),R,MyId,ClkReq},
                wait(Nodes, Master, [R|Refs], Waiting, TakeRef, MyId,NewClk, ClkReq)
            end;

            if  MyId < Id2 -> wait(Nodes, Master, Refs, [{From, Ref}|Waiting], TakeRef, MyId,NewClk,ClkReq);  %Its like an else, the only option to get there is when your request has the Same time as the other
            true -> 
                R = make_ref(),
                From ! {ok,Ref},
                From ! {request,self(),R,MyId,MyClk},
                wait(Nodes, Master, [R|Refs], Waiting, TakeRef, MyId,NewClk, ClkReq)
            end;
        {ok, Ref} ->
            NewRefs = lists:delete(Ref, Refs),
            wait(Nodes, Master, NewRefs, Waiting, TakeRef, MyId,MyClk, ClkReq);
        release ->
            ok(Waiting),            
            open(Nodes,MyId,MyClk)
    end.

ok(Waiting) -> 
    lists:map(
      fun({F,R}) -> 
        F ! {ok, R} 
      end, 
      Waiting).

held(Nodes, Waiting, MyId,Clk) -> %estado held
    receive
        {request, From, Ref, _} ->
            held(Nodes, [{From, Ref}|Waiting],MyId,Clk);
        release ->
            ok(Waiting),
            open(Nodes,MyId,Clk)
    end.
 
 
