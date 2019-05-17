@testset "Operation Model kwargs with CopperPlatePowerModel base" begin
    thermal_model = DeviceModel(PSY.ThermalDispatch, PSI.ThermalDispatch)
    load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
    devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model, :Loads =>  load_model)
    branches = Dict{Symbol, DeviceModel}(:Lines => line_model)
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))

    op_model = OperationModel(TestOptModel, CopperPlatePowerModel, 
                                            devices, 
                                            branches, 
                                            services, 
                                            c_sys5; 
                                            optimizer = GLPK_optimizer)
    j_model = op_model.canonical_model.JuMPmodel
    @test (:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 120
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericAffExpr{Float64,VariableRef}

    op_model = OperationModel(TestOptModel, CopperPlatePowerModel, 
                                            devices, 
                                            branches, 
                                            services, 
                                            c_sys14; 
                                            optimizer = OSQP_optimizer)
    j_model = op_model.canonical_model.JuMPmodel
    @test (:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 120
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 120
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 24
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericQuadExpr{Float64,VariableRef}

    op_model = OperationModel(TestOptModel, CopperPlatePowerModel, 
                                            devices, 
                                            branches, 
                                            services, 
                                            c_sys5_re; 
                                            forecast = false,
                                            optimizer = GLPK_optimizer)
    j_model = op_model.canonical_model.JuMPmodel
    @test (:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 5
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 5
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 1
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericAffExpr{Float64,VariableRef}

    op_model = OperationModel(TestOptModel, CopperPlatePowerModel, 
                                            devices, 
                                            branches, 
                                            services, 
                                            c_sys5_re; 
                                            forecast = false,
                                            parameters = false,
                                            optimizer = GLPK_optimizer)
    j_model = op_model.canonical_model.JuMPmodel
    @test !(:params in keys(j_model.ext))
    @test JuMP.num_variables(j_model) == 5
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.Interval{Float64}) == 5
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.LessThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.GreaterThan{Float64}) == 0
    @test JuMP.num_constraints(j_model,JuMP.GenericAffExpr{Float64,VariableRef},MOI.EqualTo{Float64}) == 1
    @test !((JuMP.VariableRef, MOI.ZeroOne) in JuMP.list_of_constraint_types(j_model))
    @test JuMP.objective_function_type(j_model) == JuMP.GenericAffExpr{Float64,VariableRef}
end

@testset "Operation Model Constructors with Parameters" begin
    networks = [PSI.CopperPlatePowerModel,
                PSI.StandardPTDFForm,
                PM.DCPlosslessForm, 
                PM.NFAForm,
                PM.StandardACPForm, 
                PM.StandardACRForm, 
                PM.StandardACTForm,
                PM.StandardDCPLLForm, 
                PM.AbstractLPACCForm,
                PM.SOCWRForm, 
                PM.QCWRForm,
                PM.QCWRTriForm];

    thermal_gens = [PSI.ThermalUnitCommitment,
                    PSI.ThermalDispatch,
                    PSI.ThermalRampLimited,
                    PSI.ThermalDispatchNoMin]; 
                    
        systems = [c_sys5, 
                   c_sys5_re,
                   c_sys5_bat];                     

    load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
    transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)
                    
    for net in networks, thermal in thermal_gens, system in systems
        @testset "Operation Model $(net) - $(thermal) - $(system)" begin
            thermal_model = DeviceModel(PSY.ThermalDispatch, thermal)
            devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model, :Loads =>  load_model)
            branches = Dict{Symbol, DeviceModel}(:Lines => line_model)
            services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
            op_model = OperationModel(TestOptModel, net, 
                                        devices, 
                                        branches, 
                                        services, 
                                        system; PTDF = PTDF5);     
        @test :nodal_balance_active in keys(op_model.canonical_model.expressions)
        @test (:params in keys(op_model.canonical_model.JuMPmodel.ext))                                                                   
        end
    
    
    end

end

@testset "Operation Model Constructors without Parameters" begin
    networks = [PSI.CopperPlatePowerModel,
                PSI.StandardPTDFForm,
                PM.DCPlosslessForm, 
                PM.NFAForm,
                PM.StandardACPForm, 
                PM.StandardACRForm, 
                PM.StandardACTForm,
                PM.StandardDCPLLForm, 
                PM.AbstractLPACCForm,
                PM.SOCWRForm, 
                PM.QCWRForm,
                PM.QCWRTriForm]

    thermal_gens = [PSI.ThermalUnitCommitment,
                    PSI.ThermalDispatch,
                    PSI.ThermalRampLimited,
                    PSI.ThermalDispatchNoMin]            
    
    systems = [c_sys5, 
               c_sys5_re,
               c_sys5_bat];                    

    load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
    transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)
                    
    for net in networks, thermal in thermal_gens, system in systems
        @testset "Operation Model $(net) - $(thermal) - $(system)" begin
            thermal_model = DeviceModel(PSY.ThermalDispatch, thermal)
            devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model, :Loads =>  load_model)
            branches = Dict{Symbol, DeviceModel}(:Lines => line_model)
            services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
            op_model = OperationModel(TestOptModel, net, 
                                        devices, 
                                        branches, 
                                        services, 
                                        system;
                                        parameters = false,
                                        PTDF = PTDF5)     
        @test :nodal_balance_active in keys(op_model.canonical_model.expressions)
        @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))                                                                   
        end
    
    
    end

end

#=
@testset "RTS test set" begin
    networks = [PSI.CopperPlatePowerModel,
                PSI.StandardPTDFForm,
                PM.DCPlosslessForm, 
                PM.NFAForm,
                PM.StandardACPForm, 
                PM.StandardACRForm, 
                PM.StandardACTForm,
                PM.StandardDCPLLForm, 
                PM.AbstractLPACCForm,
                PM.SOCWRForm, 
                PM.QCWRForm,
                PM.QCWRTriForm]

    thermal_gens = [PSI.ThermalUnitCommitment,
                    PSI.ThermalDispatch,
                    PSI.ThermalRampLimited,
                    PSI.ThermalDispatchNoMin]            
    
    systems = [c_sys5, 
               c_sys5_re,
               c_sys5_bat];                    

    renewable_curtailment_model = DeviceModel(PSY.RenewableCurtailment, PSI.RenewableConstantPowerFactor)
    thermal_model = DeviceModel(PSY.ThermalDispatch, PSI.ThermalDispatch)
    hvdc_model = DeviceModel(PSY.HVDCLine, PSI.DCSeriesBranch)
    #hydro = DeviceModel(PSY.HydroCurtailment, PSI.HydroCurtailment)
    transformer_model = DeviceModel(PSY.Transformer2W, PSI.ACSeriesBranch)
    tap_transformer_model = DeviceModel(PSY.TapTransformer, PSI.ACSeriesBranch)
    renewable_fix = DeviceModel(PSY.RenewableFix, PSI.RenewableFixed)
    load_model = DeviceModel(PSY.PowerLoad, PSI.StaticPowerLoad)
    line_model = DeviceModel(PSY.Line, PSI.ACSeriesBranch)
    bat = DeviceModel(PSY.GenericBattery, PSI.BookKeeping)
    
    devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model, 
                                    :Loads =>  load_model,
                                    :rc => renewable_curtailment_model,
                                    :ren_fix => renewable_fix)
    branches = Dict{Symbol, DeviceModel}(:Lines => line_model,
                                    :HVDC => hvdc_model,
                                    :tap_trafo => tap_transformer_model,
                                    :trafo => transformer_model)
    services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
    net = PSI.CopperPlatePowerModel                    

    
    for net in networks, thermal in thermal_gens, system in systems
        @testset "Operation Model $(net) - $(thermal) - $(system)" begin
            thermal_model = DeviceModel(PSY.ThermalDispatch, thermal)
            devices = Dict{Symbol, DeviceModel}(:Generators => thermal_model, :Loads =>  load_model)
            branches = Dict{Symbol, DeviceModel}(:Lines => line_model, :Transformer)
            services = Dict{Symbol, PSI.ServiceModel}(:Reserves => PSI.ServiceModel(PSY.Reserve, PSI.AbstractReservesForm))
            op_model = OperationModel(TestOptModel, net, 
                                        devices, 
                                        branches, 
                                        services, 
                                        system;
                                        parameters = false,
                                        PTDF = PTDF5)     
        @test :nodal_balance_active in keys(op_model.canonical_model.expressions)
        @test !(:params in keys(op_model.canonical_model.JuMPmodel.ext))                                                                   
        end
    
    
    end

end

=#


@testset "Build Operation Models" begin
    SCED = PSI.SCEconomicDispatch(c_sys5; optimizer = GLPK_optimizer);
    OPF = PSI.OptimalPowerFlow(c_sys5, PM.StandardACPForm, optimizer = ipopt_optimizer)
    UC = PSI.UnitCommitment(c_sys5, PM.DCPlosslessForm; optimizer = GLPK_optimizer)

    #ED_rts_p = PSI.EconomicDispatch(c_rts, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer);
    #ED_rts = PSI.EconomicDispatch(c_rts, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer, parameters = false);
    # These other tests can be enabled when CDM parser get the correct HVDC type.
    #OPF_rts = PSI.OptimalPowerFlow(sys_rts, PSI.CopperPlatePowerModel, optimizer = ipopt_optimizer)
    #UC_rts = PSI.UnitCommitment(sys_rts, PSI.CopperPlatePowerModel; optimizer = GLPK_optimizer, parameters = false)
end