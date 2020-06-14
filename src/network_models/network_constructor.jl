function construct_network!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::Type{CopperPlatePowerModel},
)
    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    get_slack_variables(psi_container.settings) &&
        add_slacks!(psi_container, CopperPlatePowerModel)
    copper_plate(psi_container, :nodal_balance_active, bus_count)

    return
end

function construct_network!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::Type{StandardPTDFModel},
)
    buses = PSY.get_components(PSY.Bus, sys)
    ac_branches = get_available_components(PSY.ACBranch, sys)
    ptdf = get_PTDF(psi_container)

    if isnothing(ptdf)
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    get_slack_variables(psi_container.settings) &&
        add_slacks!(psi_container, StandardPTDFModel)

    ptdf_networkflow(psi_container, ac_branches, buses, :nodal_balance_active, ptdf)

    dc_branches = get_available_components(PSY.DCBranch, sys)
    dc_branch_types = typeof.(dc_branches)
    for btype in Set(dc_branch_types)
        typed_dc_branches = IS.FlattenIteratorWrapper(
            btype,
            Vector([[b for b in dc_branches if typeof(b) == btype]]),
        )
        flow_variables!(psi_container, StandardPTDFModel, typed_dc_branches)
    end
    return
end

function construct_network!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::Type{T};
    instantiate_model = instantiate_nip_expr_model,
) where {T <: PM.AbstractPowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(ArgumentError("$(T) formulation is not currently supported in PowerSimulations"))
    end

    get_slack_variables(psi_container.settings) && add_slacks!(psi_container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(psi_container, T, sys, instantiate_model)
    add_pm_var_refs!(psi_container, T, sys)
    return
end

function construct_network!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::Type{T};
    instantiate_model = instantiate_bfp_expr_model,
) where {T <: PM.AbstractBFModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(ArgumentError("$(T) formulation is not currently supported in PowerSimulations"))
    end

    get_slack_variables(psi_container.settings) && add_slacks!(psi_container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(psi_container, T, sys, instantiate_model)
    add_pm_var_refs!(psi_container, T, sys)
    return
end

# Note that this function will error because these networks are currently unsupported
function construct_network!(
    psi_container::PSIContainer,
    sys::PSY.System,
    ::Type{T};
    instantiate_model = instantiate_vip_expr_model,
) where {T <: PM.AbstractIVRModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(ArgumentError("$(T) formulation is not currently supported in PowerSimulations"))
    end

    get_slack_variables(psi_container.settings) && add_slacks!(psi_container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(psi_container, T, sys, instantiate_model)
    add_pm_var_refs!(psi_container, T, sys)
    return
end
