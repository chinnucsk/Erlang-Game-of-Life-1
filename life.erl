%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Module: Life                                       %
% Author: Mariana Bustamante <marianabb@gmail.com>   %
% Description: Game of Life with concurrency         %
% Created: December 5, 2010                          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(life).
-export([init_life/5, new_cell/5, cell_loop/7, 
         calculate_future/2, communicate/7,
         calculate_max_n/4, init/0,
         which_neigh/6]).

-define(MAX_TICKS, 400).

-record(cell, {x, y, now_state}).

init() ->
    % The printer must be initialized here. Otherwise all cells must wait for it.
    printer:init(54, 24), 
    timer:sleep(2000), % Wait for the printer to be ready
    %init_life(3, 3, [" X ", " X ", " X "], 0, 0).
    %init_life(4, 4, ["    ", " XX ", " XX ", "    "], 0, 0).
    %init_life(4, 4, ["    ", " XXX", "XXX ", "    "], 0, 0).
    %init_life(6, 6, [" X    ", "  X   ", "XXX   ", "      ", "      ", "      "], 0, 0).
%%     init_life(26, 12, [" X                        ", 
%%                        "  X                       ", 
%%                        "XXX                       ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          "], 0, 0).
%%     init_life(26, 12, ["X  X                      ", 
%%                        "    X                     ", 
%%                        "X   X                     ", 
%%                        " XXXX                     ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          ", 
%%                        "                          "], 0, 0).
%%     init_life(44, 24, ["                                            ", 
%%                        "                                            ", 
%%                        "                                            ", 
%%                        "                  X  X                      ", 
%%                        "                      X                     ", 
%%                        "                  X   X                     ", 
%%                        "                   XXXX                     ", 
%%                        "                                            ", 
%%                        "                                            ", 
%%                        "                                            ", 
%%                        "                  X                         ", 
%%                        "                   XX                       ", 
%%                        "                    X                       ", 
%%                        "                    X                       ", 
%%                        "                   X                        ",
%%                        "                                            ", 
%%                        "                                            ", 
%%                        "                  X  X                      ", 
%%                        "                      X                     ", 
%%                        "                  X   X                     ", 
%%                        "                   XXXX                     ",
%%                        "                                            ", 
%%                        "                                            ", 
%%                        "                                            "], 0, 0).
    init_life(54, 24, ["                                                      ", 
                       "                                                      ", 
                       "                                                      ", 
                       "                                                      ", 
                       "                                                      ", 
                       "                                                      ", 
                       "                  XXX                                 ", 
                       "                    X                                 ", 
                       "                    X                                 ", 
                       "                   X                                  ", 
                       "                                 XXX              XX  ", 
                       "                   X             X                 X  ",  
                       "                    X            X                    ", 
                       "  X                 X             X                   ", 
                       "  XX              XXX                                 ",
                       "                                  X                   ", 
                       "                                 X                    ", 
                       "                                 X                    ", 
                       "                                 XXX                  ", 
                       "                                                      ", 
                       "                                                      ",
                       "                                                      ", 
                       "                                                      ", 
                       "                                                      "], 0, 0).



% Function that receives the initial state and spawns a 
% process for every square. Every process must have a cell
% with coordinates and state.
% The last argument is a list of strings in which every string
% represents one row of the board.
% Example board: [" X ", " X ", " X "]
% Example call: life:init_life(3, 3, [" X ", " X ", " X "], 0, 0).
% Warning: It does not verify the correctness of Width, Height or Board.
init_life(_, _, [], _, _) ->
    ok;
init_life(Width, Height, [Row | Board], N_row, _) when (Row == []) -> 
    init_life(Width, Height, Board, N_row + 1, 0);
init_life(Width, Height, [ [X|XS] | Board], N_row, N_col) ->
    S_row = integer_to_list(N_row),
    S_col = integer_to_list(N_col),
    
    if
        X == 88 -> State = 'alive'; % 88 is ISO for X
        true -> State = 'dead'
    end,
    Pid = spawn(fun () -> new_cell(Width, Height, N_col, N_row, State) end),
    %io:format("Registering PID ~p as ~p~n", [Pid, list_to_atom(S_col ++ S_row)]),
    register(list_to_atom(S_col ++"_"++ S_row), Pid),
    init_life(Width, Height, [XS | Board], N_row, N_col + 1).


% Creates a new Cell with the first state and makes the
% process execute cell_loop.
new_cell(W, H, X, Y, State) -> 
    Cell = #cell{x = X, y = Y, now_state = State},

    % Calculate Max_neigh according to the coordinates
    Max_n = calculate_max_n(X, Y, W, H),

    io:format("New cell ~p created with Max_neigh = ~p~n", [Cell, Max_n]),
    %timer:sleep(1000), % Wait for the printer
    cell_loop(W, H, Cell, 0, Max_n, 0, 0).


% Calculates the Maximum number of neighbours for a cell.
% Considers 3 cases: center, corner and border.
calculate_max_n(X, Y, W, H) ->
    if 
        (X =/= 0) and (Y =/= 0) and (X =/= W-1) and (Y =/= H-1) ->
            8;
        ((X == 0) or (X+1 == W)) and ((Y == 0) or (Y+1 == H)) ->
            3;
        (((X == 0) or (X+1 == W)) and ((Y > 0) and (Y < H))) or
        (((Y == 0) or (Y+1 == H)) and ((X > 0) and (X < W))) ->
            5
    end.


% The function that controls the actions that every cell
% must accomplish:
% 1. Verify that we have arrived at the maximum number of ticks.
% 2. Send my status to all my neighbours
% 3. Check if I have all my neighbours status. 
%    If I do, calculate my next status, send to the printer and change it.
% 3. Wait to receive status from my neighbours from the tick that interests me.
cell_loop(W, H, Cell, Num_neigh, Max_neigh, Alive_count, Tick) ->

    if
        (Tick == ?MAX_TICKS) ->
            self() ! suicide_please;
        true -> ok
    end,

    % Create a process to send my status to all my neighbours in the beginning 
    % of every tick.
    % We know that at the start of a tick Num_neigh == 0
    if (Num_neigh == 0) ->
            Outbox = which_neigh(Cell#cell.x, Cell#cell.y, W, H, Max_neigh, [0, 1, 2, 3, 4, 5, 6, 7]),
            communicate(Cell#cell.x, Cell#cell.y, Cell#cell.now_state, Outbox, W, H, Tick);
       true -> ok
    end,
    
    % Check if I have all my neighbors status. If I do, calculate my next status.
    if (Num_neigh == Max_neigh) ->
            %io:format("I am cell ~p and I will calculate my next status~n", [Cell]),
            Future = calculate_future(Alive_count, Cell#cell.now_state),

            % Send my status in the current tick to the printer
            printer ! {print_cell, Cell#cell.x, Cell#cell.y, Future, Tick},
            
            % Loop again with the next tick
            cell_loop(W, H, {cell, Cell#cell.x, Cell#cell.y, Future}, 0, Max_neigh, 0, Tick+1);

       true -> ok
    end,
    
    receive 
        % Only process the message if N_tick corresponds with my Tick
        {st_sent, N_status, N_tick} when (N_tick == Tick) -> 
            case N_status of
                'alive' -> cell_loop(W, H, Cell, Num_neigh+1, Max_neigh, Alive_count+1, Tick);
                'dead' -> cell_loop(W, H, Cell, Num_neigh+1, Max_neigh, Alive_count, Tick)
            end;
        suicide_please ->
            void
    end.


% Creates a list of the useful neighbours of a cell.
% Useful must be [0, 1, 2, 3, 4, 5, 6, 7] at the beginning
which_neigh(_, _, _, _, Max_neigh, Useful) 
  when (length(Useful) == Max_neigh) -> Useful;

which_neigh(0, Y, W, H, Max_neigh, Useful) ->     
    which_neigh(W, Y, W, H, Max_neigh, Useful -- [0, 3, 5]);

which_neigh(X, 0, W, H, Max_neigh, Useful) ->
    which_neigh(X, H, W, H, Max_neigh, Useful -- [5, 6, 7]);

which_neigh(X, Y, W, H, Max_neigh, Useful) 
  when (X+1 == W) ->
    which_neigh(W, Y, W, H, Max_neigh, Useful -- [2, 4, 7]);

which_neigh(X, Y, W, H, Max_neigh, Useful) 
  when (Y+1 == H) ->
    which_neigh(X, H, W, H, Max_neigh, Useful -- [0, 1, 2]).


% Sends the status of Cell to the neighbours provided on thw
% Useful list. 
communicate(_, _, _, [], _, _, _) ->
    %io:format("Cell ~p~p sent state to all its neighbours~n", [X, Y]),
    ok;
communicate(X, Y, Status, [Neighbour | Useful], W, H, Tick) ->
    case Neighbour of
        0 -> Name = list_to_atom(integer_to_list(X-1) ++"_"++ integer_to_list(Y+1)); %NW
        1 -> Name = list_to_atom(integer_to_list(X) ++"_"++ integer_to_list(Y+1));   %N
        2 -> Name = list_to_atom(integer_to_list(X+1) ++"_"++ integer_to_list(Y+1)); %NE
        3 -> Name = list_to_atom(integer_to_list(X-1) ++"_"++ integer_to_list(Y));   %W
        4 -> Name = list_to_atom(integer_to_list(X+1) ++"_"++ integer_to_list(Y));   %E
        5 -> Name = list_to_atom(integer_to_list(X-1) ++"_"++ integer_to_list(Y-1)); %SW
        6 -> Name = list_to_atom(integer_to_list(X) ++"_"++ integer_to_list(Y-1));   %S
        7 -> Name = list_to_atom(integer_to_list(X+1) ++"_"++ integer_to_list(Y-1))  %SE
    end,

    %io:format("I am cell ~p~p, sending my status (~p) to cell ~p~n", [X, Y, Status, Name]),
    Name ! {st_sent, Status, Tick},
    communicate(X, Y, Status, Useful, W, H, Tick).


% Applies the rules and calculates the next state according 
% to the neighborhood and the current status.
calculate_future(Alive_count, 'dead') when (Alive_count == 3) -> 'alive';
calculate_future(_, 'dead') -> 'dead';
calculate_future(Alive_count, 'alive') when (Alive_count < 2) or (Alive_count > 3) -> 'dead';
calculate_future(Alive_count, 'alive') when (Alive_count == 2) or (Alive_count == 3) -> 'alive'.
