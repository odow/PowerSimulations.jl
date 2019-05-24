
function _make_container_array(V::DataType, ax...; kwargs...)

    parameters = get(kwargs, :parameters, true)

    # While JuMP fixes the isassigned problems
     # While JuMP fixes the isassigned problems
    #=
    if parameters
            cont = JuMP.Containers.DenseAxisArray{PGAE{V}}(undef, ax...)
            _remove_undef!(cont.data)
        return cont
    else
            cont = JuMP.Containers.DenseAxisArray{GAE{V}}(undef, ax...)
            _remove_undef!(cont.data)
        return cont
    end
    =#

    if parameters
        return JuMP.Containers.DenseAxisArray{PGAE{V}}(undef, ax...)
    else
        return JuMP.Containers.DenseAxisArray{GAE{V}}(undef, ax...)
    end

    return

end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractPowerFormulation}

    return Dict{Symbol, JuMP.Containers.DenseAxisArray}(:nodal_balance_active =>  _make_container_array(V, bus_numbers, time_steps; kwargs...),
                                                        :nodal_balance_reactive => _make_container_array(V, bus_numbers, time_steps; kwargs...))
end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    return Dict{Symbol, JuMP.Containers.DenseAxisArray}(:nodal_balance_active => _make_container_array(V, bus_numbers, time_steps; kwargs...))
end


function _canonical_model_init(bus_numbers::Vector{Int64},
                              optimizer::Union{Nothing,JuMP.OptimizerFactory},
                              transmission::Type{S},
                              time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractPowerFormulation}

    parameters = get(kwargs, :parameters, true)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)

    ps_model = CanonicalModel(jump_model,
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            zero(JuMP.GenericAffExpr{Float64, V}),
                            _make_expressions_dict(transmission, V, bus_numbers, time_steps; kwargs...),
                            parameters ? Dict{Symbol,JuMP.Containers.DenseAxisArray}() : nothing,
                            Dict{Symbol,Array{InitialCondition}}(),
                            nothing);

    return ps_model

end

function _canonical_model_init(bus_numbers::Vector{Int64},
                               optimizer::Union{Nothing,JuMP.OptimizerFactory},
                               transmission::Type{S},
                               time_steps::UnitRange{Int64}; kwargs...) where {S <: Union{StandardPTDFForm, CopperPlatePowerModel}}

    parameters = get(kwargs, :parameters, true)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)

    ps_model = CanonicalModel(jump_model,
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission, V, bus_numbers, time_steps; kwargs...),
                              parameters ? Dict{Symbol,JuMP.Containers.DenseAxisArray}() : nothing,
                              Dict{Symbol,Array{InitialCondition}}(),
                              nothing);

    return ps_model

end

function  build_canonical_model(transmission::Type{T},
                                devices::Dict{Symbol, DeviceModel},
                                branches::Dict{Symbol, DeviceModel},
                                services::Dict{Symbol, ServiceModel},
                                sys::PSY.System,
                                resolution::Dates.Period,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {T <: PM.AbstractPowerFormulation}


    forecast = get(kwargs, :forecast, true)

    if forecast
        first_key = PSY.get_forecasts_initial_time(sys)
        horizon = PSY.get_forecasts_horizon(sys)
        time_steps = 1:horizon
    else
        time_steps = 1:1
    end

    bus_numbers = [b.number for b in PSY.get_components(PSY.Bus, sys)]

    ps_model = _canonical_model_init(bus_numbers, optimizer, transmission, time_steps; kwargs...)

    # Build Injection devices
    for mod in devices
        construct_device!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Build Branches
    for mod in branches
        construct_device!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Build Network
    construct_network!(ps_model, transmission, sys, time_steps; kwargs...)

    #Build Service
    for mod in services
        #construct_service!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Objective Function
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)

    return ps_model

end