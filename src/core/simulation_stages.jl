######## Internal Simulation Object Structs ########
mutable struct StageInternal
    number::Int
    name::String
    executions::Int
    execution_count::Int
    end_of_interval_step::Int
    # This line keeps track of the executions of a stage relative to other stages.
    # This might be needed in the future to run multiple stages. For now it is disabled
    #synchronized_executions::Dict{Int, Int} # Number of executions per upper level stage step
    psi_container::PSIContainer
    # Caches are stored in set because order isn't relevant and they should be unique
    caches::Set{CacheKey}
    chronolgy_dict::Dict{Int, <:FeedForwardChronology}
    status::BUILD_STATUS
    base_conversion::Bool
    write_path::String
    ext::Dict{String, Any}
    function StageInternal(
        number,
        name,
        executions,
        execution_count,
        psi_container;
        ext = Dict{String, Any}(),
    )
        new(
            number,
            name,
            executions,
            execution_count,
            0,
            psi_container,
            Set{CacheKey}(),
            Dict{Int, FeedForwardChronology}(),
            EMPTY,
            true,
            "",
            ext,
        )
    end
end

# TODO: Add DocString
@doc raw"""
    Stage({M<:AbstractOperationsProblem}
        template::OperationsProblemTemplate
        sys::PSY.System
        optimizer::JuMP.MOI.OptimizerWithAttributes
        internal::Union{Nothing, StageInternal}
        )
"""
mutable struct Stage{M <: AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    internal::Union{Nothing, StageInternal}

    function Stage{M}(
        template::OperationsProblemTemplate,
        sys::PSY.System,
        settings::PSISettings,
        jump_model::Union{Nothing, JuMP.AbstractModel} = nothing,
    ) where {M <: AbstractOperationsProblem}
        internal = StageInternal(0, "", 0, 0, PSIContainer(sys, settings, jump_model))
        new{M}(template, sys, internal)
    end
end

function Stage{M}(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    PTDF = nothing,
    warm_start = true,
    balance_slack_variables = false,
    services_slack_variables = false,
    constraint_duals = Vector{Symbol}(),
    system_to_file = true,
    export_pwl_vars = false,
    allow_fails = false,
) where {M <: AbstractOperationsProblem}
    settings = PSISettings(
        sys;
        optimizer = optimizer,
        use_parameters = true,
        warm_start = warm_start,
        balance_slack_variables = balance_slack_variables,
        services_slack_variables = services_slack_variables,
        constraint_duals = constraint_duals,
        system_to_file = system_to_file,
        export_pwl_vars = export_pwl_vars,
        allow_fails = allow_fails,
        PTDF = PTDF,
    )
    return Stage{M}(template, sys, settings, jump_model)
end

"""
    Stage(::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel}=nothing;
    kwargs...) where {M<:AbstractOperationsProblem}
This builds the optimization problem of type M with the specific system and template for the simulation stage
# Arguments
- `::Type{M} where M<:AbstractOperationsProblem`: The abstract operation model type
- `template::OperationsProblemTemplate`: The model reference made up of transmission, devices,
                                          branches, and services.
- `sys::PSY.System`: the system created using Power Systems
- `jump_model::Union{Nothing, JuMP.AbstractModel}`: Enables passing a custom JuMP model. Use with care
# Output
- `Stage::Stage`: The operation model containing the model type, unbuilt JuMP model, Power
Systems system.
# Example
```julia
template = OperationsProblemTemplate(CopperPlatePowerModel, devices, branches, services)
stage = Stage(MyOpProblemType template, system, optimizer)
```
# Accepted Key Words
- `initial_time::Dates.DateTime`: Initial Time for the model solve
- `PTDF::PTDF`: Passes the PTDF matrix into the optimization model for StandardPTDFModel networks.
- `warm_start::Bool` True will use the current operation point in the system to initialize variable values. False initializes all variables to zero. Default is true
- `balance_slack_variables::Bool` True will add slacks to the system balance constraints
- `services_slack_variables::Bool` True will add slacks to the services requirement constraints
- `export_pwl_vars::Bool` True will write the results of the piece-wise-linear intermediate variables. Slows down the simulation process significantly
- `allow_fails::Bool`  True will allow the simulation to continue if the optimizer can't find a solution. Use with care, can lead to unwanted behaviour or results
"""
function Stage(
    ::Type{M},
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
) where {M <: AbstractOperationsProblem}
    return Stage{M}(template, sys, optimizer, jump_model; kwargs...)
end

function Stage(
    template::OperationsProblemTemplate,
    sys::PSY.System,
    optimizer::JuMP.MOI.OptimizerWithAttributes,
    jump_model::Union{Nothing, JuMP.AbstractModel} = nothing;
    kwargs...,
)
    return Stage{GenericOpProblem}(template, sys, optimizer, jump_model; kwargs...)
end

is_stage_built(stage::Stage) = stage.internal.status == BUILT
is_stage_empty(stage::Stage) = stage.internal.status == EMPTY
get_end_of_interval_step(stage::Stage) = stage.internal.end_of_interval_step
get_execution_count(stage::Stage) = stage.internal.execution_count
get_executions(stage::Stage) = stage.internal.executions
function get_initial_time(stage::Stage{T}) where {T <: AbstractOperationsProblem}
    return get_initial_time(get_settings(stage))
end
get_name(stage::Stage) = stage.internal.name
get_number(stage::Stage) = stage.internal.number
get_psi_container(stage::Stage) = stage.internal.psi_container
function get_resolution(stage::Stage{T}) where {T <: AbstractOperationsProblem}
    resolution = PSY.get_time_series_resolution(get_system(stage))
    return IS.time_period_conversion(resolution)
end
get_settings(stage::Stage) = get_psi_container(stage).settings
get_system(stage::Stage) = stage.sys
get_template(stage::Stage) = stage.template
get_write_path(stage::Stage) = stage.internal.write_path
warm_start_enabled(stage::Stage) = get_warm_start(get_psi_container(stage).settings)

set_write_path!(stage::Stage, path::AbstractString) = stage.internal.write_path = path
set_stage_status!(stage::Stage, status::BUILD_STATUS) = stage.internal.status = status

function reset!(stage::Stage{T}) where {T <: AbstractOperationsProblem}
    stage.internal.execution_count = 0
    container = PSIContainer(get_system(stage), get_settings(stage), nothing)
    stage.internal.psi_container = container
    set_stage_status!(stage, EMPTY)
    return
end

function build_pre_step!(
    stage::Stage,
    initial_time::Dates.DateTime,
    horizon::Int,
    stage_interval::Dates.Period,
)
    if !is_stage_empty(stage)
        @info "Stage $(get_name(stage)) status not EMPTY. Resetting"
        reset!(stage)
    end
    settings = get_settings(stage)
    # Horizon and initial time are set here because the information is specified in the
    # Simulation Sequence object and not at the stage creation.
    set_horizon!(settings, horizon)
    set_initial_time!(settings, initial_time)
    stage_resolution = get_resolution(stage)
    stage.internal.end_of_interval_step = Int(stage_interval / stage_resolution)
    set_stage_status!(stage, IN_PROGRESS)
    return
end

function build!(
    stage::Stage{M},
    initial_time::Dates.DateTime,
    horizon::Int,
    stage_interval::Dates.Period,
) where {M <: PowerSimulationsOperationsProblem}
    build_pre_step!(stage, initial_time, horizon, stage_interval)
    psi_container = get_psi_container(stage)
    system = get_system(stage)
    _build!(psi_container, get_template(stage), system)
    settings = get_settings(stage)
    @assert get_horizon(settings) == length(psi_container.time_steps)
    write_path = get_write_path(stage)
    write_psi_container(
        get_psi_container(stage),
        joinpath(
            write_path,
            "models_json",
            "Stage$(stage.internal.number)_optimization_model.json",
        ),
    )
    set_stage_status!(stage, BUILT)
    return
end

function run_stage!(
    step::Int,
    stage::Stage{M},
    start_time::Dates.DateTime,
    store::SimulationStore,
) where {M <: PowerSimulationsOperationsProblem}
    @assert get_psi_container(stage).JuMPmodel.moi_backend.state != MOIU.NO_OPTIMIZER
    status = RUNNING
    timed_log = Dict{Symbol, Any}()
    model = get_psi_container(stage).JuMPmodel

    _, timed_log[:timed_solve_time], timed_log[:solve_bytes_alloc], timed_log[:sec_in_gc] =
        @timed JuMP.optimize!(model)

    model_status = JuMP.primal_status(model)
    stats = OptimizerStats(step, get_number(stage), start_time, model, timed_log)
    append_optimizer_stats!(store, stats)

    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        return FAILED_RUN
    else
        status = SUCCESSFUL_RUN
    end
    write_model_results!(store, stage, start_time)
    stage.internal.execution_count += 1
    # Reset execution count at the end of step
    if stage.internal.execution_count == stage.internal.executions
        stage.internal.execution_count = 0
    end
    return status
end

function write_model_results!(store, stage, timestamp)
    psi_container = get_psi_container(stage)

    if is_milp(get_psi_container(stage))
        @warn "Stage $(stage.internal.number) is a MILP, duals can't be exported"
    else
        _write_model_dual_results!(store, psi_container, stage, timestamp)
    end

    _write_model_parameter_results!(store, psi_container, stage, timestamp)
    _write_model_variable_results!(store, psi_container, stage, timestamp)
    return
end

function _write_model_dual_results!(store, psi_container, stage, timestamp)
    stage_name = Symbol(get_name(stage))
    for name in get_constraint_duals(psi_container.settings)
        constraint = get_constraint(psi_container, name)
        write_result!(
            store,
            stage_name,
            STORE_CONTAINER_DUALS,
            name,
            timestamp,
            to_array(constraint),
        )
    end
end

function _write_model_parameter_results!(store, psi_container, stage, timestamp)
    parameters = get_parameters(psi_container)
    (isnothing(parameters) || isempty(parameters)) && return

    horizon = get_horizon(get_settings(stage))
    stage_name = Symbol(get_name(stage))
    for (name, container) in parameters
        !isa(container.update_ref, UpdateRef{<:PSY.Component}) && continue
        param_array = get_parameter_array(container)
        multiplier_array = get_multiplier_array(container)
        @assert_op length(axes(param_array)) == 2
        num_columns = size(param_array)[1]
        data = Array{Float64}(undef, horizon, num_columns)
        for r_ix in param_array.axes[2], (c_ix, name) in enumerate(param_array.axes[1])
            val1 = _jump_value(param_array[name, r_ix])
            val2 = multiplier_array[name, r_ix]
            data[r_ix, c_ix] =
                _jump_value(param_array[name, r_ix]) * (multiplier_array[name, r_ix])
        end

        write_result!(store, stage_name, STORE_CONTAINER_PARAMETERS, name, timestamp, data)
    end
end

function _write_model_variable_results!(store, psi_container, stage, timestamp)
    stage_name = Symbol(get_name(stage))
    for (name, variable) in get_variables(psi_container)
        write_result!(
            store,
            stage_name,
            STORE_CONTAINER_VARIABLES,
            name,
            timestamp,
            to_array(variable),
        )
    end
end

# Here because requires the stage to be defined
# This is a method a user defining a custom cache will have to define. This is the definition
# in PSI for the building the TimeStatusChange
function get_initial_cache(cache::AbstractCache, stage::Stage)
    throw(ArgumentError("Initialization method for cache $(typeof(cache)) not defined"))
end

function get_initial_cache(cache::TimeStatusChange, stage::Stage)
    ini_cond_on =
        get_initial_conditions(get_psi_container(stage), TimeDurationON, cache.device_type)

    ini_cond_off =
        get_initial_conditions(get_psi_container(stage), TimeDurationOFF, cache.device_type)

    device_axes = Set((
        PSY.get_name(ic.device) for ic in Iterators.Flatten([ini_cond_on, ini_cond_off])
    ),)
    value_array = JuMP.Containers.DenseAxisArray{Dict{Symbol, Any}}(undef, device_axes)

    for ic in ini_cond_on
        device_name = PSY.get_name(ic.device)
        condition = get_condition(ic)
        status = (condition > 0.0) ? 1.0 : 0.0
        value_array[device_name] = Dict(:count => condition, :status => status)
    end

    for ic in ini_cond_off
        device_name = PSY.get_name(ic.device)
        condition = get_condition(ic)
        status = (condition > 0.0) ? 0.0 : 1.0
        if value_array[device_name][:status] != status
            throw(IS.ConflictingInputsError("Initial Conditions for $(device_name) are not compatible. The values provided are invalid"))
        end
    end

    return value_array
end

function get_initial_cache(cache::StoredEnergy, stage::Stage)
    ini_cond_level =
        get_initial_conditions(get_psi_container(stage), EnergyLevel, cache.device_type)

    device_axes = Set([PSY.get_name(ic.device) for ic in ini_cond_level],)
    value_array = JuMP.Containers.DenseAxisArray{Float64}(undef, device_axes)
    for ic in ini_cond_level
        device_name = PSY.get_name(ic.device)
        condition = get_condition(ic)
        value_array[device_name] = condition
    end
    return value_array
end

function get_timestamps(stage::Stage, start_time::Dates.DateTime)
    resolution = get_resolution(stage)
    horizon = get_psi_container(stage).time_steps[end]
    range_time = collect(start_time:resolution:(start_time + resolution * horizon))
    time_stamp = DataFrames.DataFrame(Range = range_time[:, 1])

    return time_stamp
end

function write_data(stage::Stage, save_path::AbstractString; kwargs...)
    write_data(get_psi_container(stage), save_path; kwargs...)
    return
end

struct StageSerializationWrapper
    template::OperationsProblemTemplate
    sys::String
    settings::PSISettings
    stage_type::DataType
end
