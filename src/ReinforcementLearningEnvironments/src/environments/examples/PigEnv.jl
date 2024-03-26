export PigEnv

const PIG_TARGET_SCORE = 100
const PIG_N_SIDES = 6

mutable struct PigEnv{N} <: AbstractEnv
    scores::Vector{Int}
    current_player::Player
    is_chance_player_active::Bool
    tmp_score::Int
end

"""
    PigEnv(;n_players=2)

See [wiki](https://en.wikipedia.org/wiki/Pig_(dice_game)) for explanation of this game.

Here we use it to demonstrate how to write a game with more than 2 players.
"""
PigEnv(; n_players=2) = PigEnv{n_players}(zeros(Int, n_players), Player(1), false, 0)

function next_player(env::PigEnv)
    next_player_int = parse(Int64, string(env.current_player.name)) + 1
    if next_player_int > length(players(env))
        return Player(1)
    else
        return Player(next_player_int)
    end
end

function RLBase.reset!(env::PigEnv)
    fill!(env.scores, 0)
    env.current_player = Player(1)
    env.is_chance_player_active = false
    env.tmp_score = 0
end

RLBase.current_player(env::PigEnv) =
    env.is_chance_player_active ? CHANCE_PLAYER : env.current_player
RLBase.players(env::PigEnv) = Player.(1:length(env.scores))
RLBase.action_space(env::PigEnv, ::Player) = (:roll, :hold)
RLBase.action_space(env::PigEnv, ::ChancePlayer) = Base.OneTo(PIG_N_SIDES)

RLBase.prob(env::PigEnv, ::ChancePlayer) = fill(1 / 6, 6)  # TODO: uniform distribution, more memory efficient

RLBase.state(env::PigEnv, ::Observation{Vector{Int}}, p::AbstractPlayer) = env.scores
RLBase.state_space(env::PigEnv, ::Observation, p::AbstractPlayer) = ArrayProductDomain([0 .. (PIG_TARGET_SCORE + PIG_N_SIDES - 1) for _ in env.scores])


RLBase.is_terminated(env::PigEnv) = any(s >= PIG_TARGET_SCORE for s in env.scores)

function RLBase.reward(env::PigEnv, player::AbstractPlayer)
    winner = findfirst(>=(PIG_TARGET_SCORE), env.scores)
    if isnothing(winner)
        0
    elseif winner == player
        1
    else
        -1
    end
end

function RLBase.act!(env::PigEnv, action, player::Player)
    if action == :roll
        env.is_chance_player_active = true
    else
        env.scores[parse(Int64, string(player.name))] += env.tmp_score
        env.tmp_score = 0
        env.current_player = next_player(env)
    end
end

function RLBase.act!(env::PigEnv, action, ::ChancePlayer)
    env.is_chance_player_active = false
    if action == 1
        env.tmp_score = 0
        env.current_player = next_player(env)
    else
        env.tmp_score += action
    end
end

RLBase.NumAgentStyle(::PigEnv{N}) where {N} = MultiAgent(N)
RLBase.DynamicStyle(::PigEnv) = SEQUENTIAL
RLBase.ActionStyle(::PigEnv) = MINIMAL_ACTION_SET
RLBase.InformationStyle(::PigEnv) = PERFECT_INFORMATION
RLBase.StateStyle(::PigEnv) = Observation{Vector{Int}}()
RLBase.RewardStyle(::PigEnv) = TERMINAL_REWARD
RLBase.UtilityStyle(::PigEnv) = CONSTANT_SUM
RLBase.ChanceStyle(::PigEnv) = EXPLICIT_STOCHASTIC
