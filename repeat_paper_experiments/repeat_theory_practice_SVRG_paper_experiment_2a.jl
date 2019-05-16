"""
### "Towards closing the gap between the theory and practice of SVRG", Francis Bach, Othmane Sebbouh, Nidham Gazagnadou, Robert M. Gower (2019)

## --- EXPERIMENT 2.A ---
Goal: Compare SVRG variants: Bubeck version, Free-SVRG, Leap-SVRG and Loopless-SVRG-Decreasing for nice sampling (b=1).

## --- THINGS TO CHANGE BEFORE RUNNING ---
- line 37: enter your full path to the "StochOpt.jl/" repository in the *path* variable

## --- HOW TO RUN THE CODE ---
To run this experiment, open a terminal, go into the "StochOpt.jl/" repository and run the following command:
>julia -p <number_of_processor_to_add> repeat_paper_experiments/repeat_theory_practice_SVRG_paper_experiment_2a.jl <boolean>
where <number_of_processor_to_add> has to be replaced by the user.
- If <boolean> == false, only the first problem (ijcnn1_full + column-scaling + lambda=1e-1) is launched
- Else, <boolean> == true, all XX problems are launched

## --- EXAMPLE OF RUNNING TIME ---
Running time of the first problem only when adding XX processors on XXXX
XXXX, around XXmin
Running time of all problems when adding XX processors on XXXX
XXXX, around XXmin

## --- SAVED FILES ---
For each problem (data set + scaling process + regularization)
- the empirical total complexity v.s. mini-batch size plots are saved in ".pdf" format in the "./experiments/sharp_SVRG/exp2a/figures/" folder
- the results of the simulations (mini-batch grid, empirical complexities, optimal empirical mini-batch size, etc.) are saved in ".jld" format in the "./experiments/sharp_SVRG/exp2a/outputs/" folder
"""


## Bash input
all_problems = parse(Bool, ARGS[1]) # run 1 (false) or all the 12 problems (true)

using Distributed

@everywhere begin
    path = "/cal/homes/ngazagnadou/StochOpt.jl/"

    using JLD
    using Plots
    using StatsBase
    using Match
    using Combinatorics
    using Random
    using Printf
    using LinearAlgebra
    using Statistics
    using Base64
    using Formatting
    using SharedArrays

    include("$(path)src/StochOpt.jl")

    pyplot() # No problem with pyplot when called in @everywhere statement
end

## Path settings
#region
save_path = "$(path)experiments/theory_practice_SVRG/"
if !isdir(save_path)
    mkdir(save_path)
    mkdir("$(save_path)exp2a/")
end
save_path = "$(save_path)exp2a/"
# Create saving directories if not existing
if !isdir("$(save_path)data/")
    mkdir("$(save_path)data/")
end
if !isdir("$(save_path)figures/")
    mkdir("$(save_path)figures/")
end
if !isdir("$(save_path)outputs/")
    mkdir("$(save_path)outputs/")
end
#endregion

## Experiments settings
if all_problems
    problems = 1:10
else
    problems = 1:1
end

datasets = ["slice", "slice",                                   # scaled,   n =  53,500, d =    384
            "YearPredictionMSD_full", "YearPredictionMSD_full", # scaled,   n = 515,345, d =     90
            "ijcnn1_full", "ijcnn1_full",                       # scaled,   n = 141,691, d =     22
            "covtype_binary", "covtype_binary",                 # scaled,   n = 581,012, d =     54
            "real-sim", "real-sim"]                             # scaled, n =  72,309, d = 20,958

lambdas = [10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3)]

## Set smaller number of skipped iteration for finer estimations (yet, longer simulations)
skip_error = [10000,         # XXmin with XXX
              10000,         # XXmin with XXX
              100000,        # XXmin with XXX
              100000,        # XXmin with XXX
              50000,         # XXmin with XXX
              50000,         # XXmin with XXX
              100000,        # XXmin with XXX
              100000,        # XXmin with XXX
              100000,        # XXmin with XXX
              100000]        # XXmin with XXX

max_epochs = 2
precision = 10.0^(-4) # 10.0^(-6)

@sync @distributed for idx_prob in problems
    data = datasets[idx_prob]
    scaling = "column-scaling"
    lambda = lambdas[idx_prob]
    skip_parameter = skip_error[idx_prob]
    println("EXPERIMENT : ", idx_prob, " over ", length(problems))
    @printf "Inputs: %s + %s + %1.1e \n" data scaling lambda

    Random.seed!(1)

    ## Loading the data
    println("--- Loading data ---")
    data_path = "$(path)data/";
    X, y = loadDataset(data_path, data)

    ## Setting up the problem
    println("\n--- Setting up the selected problem ---")
    options = set_options(tol=precision, max_iter=10^8,
                          max_epocs=max_epochs,
                          max_time=60.0*2.0, # 60.0*60.0*10.0
                          skip_error_calculation=skip_parameter,
                          batchsize=1,
                          regularizor_parameter="normalized",
                          initial_point="zeros", # is fixed not to add more randomness
                          force_continue=false) # force continue if diverging or if tolerance reached

    u = unique(y)
    if length(u) < 2
        error("Wrong number of possible outputs")
    elseif length(u) == 2
        println("Binary output detected: the problem is set to logistic regression")
        prob = load_logistic_from_matrices(X, y, data, options, lambda=lambda, scaling=scaling)
    else
        println("More than three modalities in the outputs: the problem is set to ridge regression")
        prob = load_ridge_regression(X, y, data, options, lambda=lambda, scaling=scaling)
    end

    X = nothing
    y = nothing

    n = prob.numdata

    ## Running methods
    OUTPUTS = [] # list of saved outputs

    ################################################################################
    ########################## DOUBLE-LOOP SVRG VARIANTS ###########################
    ################################################################################

    ## SVRG-Bubeck with 1-nice sampling ( m = m^*, b = 1, step size = gamma^* )
    numinneriters = -1                 # theoretical inner loop size (m^* = 20*Lmax/mu) set in initiate_SVRG_bubeck
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step size (gamma^* = 1/10*Lmax) set in boot_SVRG_bubeck
    sampling = build_sampling("nice", n, options)
    bubeck = initiate_SVRG_bubeck(prob, options, sampling, numinneriters=numinneriters)

    println("-------------------- WARM UP --------------------")
    tmp = options.max_epocs
    options.max_epocs = 3
    minimizeFunc(prob, bubeck, options)
    options.max_epocs = tmp
    bubeck.reset(prob, bubeck, options)
    println("-------------------------------------------------")

    out_bubeck = minimizeFunc(prob, bubeck, options)

    str_m_bubeck = @sprintf "%d" bubeck.numinneriters
    str_step_bubeck = @sprintf "%.2e" bubeck.stepsize
    out_bubeck.name = latexstring("$(out_bubeck.name) \$(m^* = $str_m_bubeck, b = 1, \\gamma^* = $str_step_bubeck)\$")
    OUTPUTS = [OUTPUTS; out_bubeck]

    ## Free-SVRG with 1-nice sampling ( m = n, b = 1, step size = gamma^*(1) )
    numinneriters = n                  # inner loop size set to the number of data points
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step size set in boot_Free_SVRG

    sampling = build_sampling("nice", n, options)
    free = initiate_Free_SVRG(prob, options, sampling, numinneriters=numinneriters, averaged_reference_point=true)
    out_free = minimizeFunc(prob, free, options)

    str_m_free = @sprintf "%d" free.numinneriters
    str_step_free = @sprintf "%.2e" free.stepsize
    out_free.name = latexstring("$(out_free.name) \$(m = n = $str_m_free, b = 1, \\gamma^*(1) = $str_step_free)\$")
    OUTPUTS = [OUTPUTS; out_free]


    ################################################################################
    ############################ LOOPLESS SVRG VARIANTS ############################
    ################################################################################

    ## Leap-SVRG with 1-nice sampling ( p = 1/n, b = 1, step sizes = {eta^*=1/L, alpha^*(b)} )
    proba = 1/n                        # update probability set to the inverse of the number of data points
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step sizes set in boot_Leap_SVRG
    sampling = build_sampling("nice", n, options)
    leap = initiate_Leap_SVRG(prob, options, sampling, proba)

    out_leap = minimizeFunc(prob, leap, options)

    str_proba_leap = @sprintf "%.2e" proba
    str_step_sto_leap = @sprintf "%.2e" leap.stochastic_stepsize
    str_step_grad_leap = @sprintf "%.2e" leap.gradient_stepsize
    out_leap.name = latexstring("$(out_leap.name) \$(p = 1/n = $str_proba_leap, b = 1, \\eta^* = $str_step_grad_leap, \\alpha^*(1) = $str_step_sto_leap)\$")
    OUTPUTS = [OUTPUTS; out_leap]


    ## L_SVRG_D with 1-nice sampling ( p = 1/n, b = 1, step size = gamma^*(b) )
    proba = 1/n                        # update probability set to the inverse of the number of data points
    options.batchsize = 1              # mini-batch size set to 1
    options.stepsize_multiplier = -1.0 # theoretical step sizes set in boot_L_SVRG_D
    sampling = build_sampling("nice", n, options)
    decreasing = initiate_L_SVRG_D(prob, options, sampling, proba)

    out_decreasing = minimizeFunc(prob, decreasing, options)

    str_proba_decreasing = @sprintf "%.2e" proba
    str_step_decreasing = @sprintf "%.2e" decreasing.stepsize
    out_decreasing.name = latexstring("$(out_decreasing.name) \$(p = 1/n = $str_proba_decreasing, b = 1, \\gamma^*(1) = $str_step_decreasing)\$")
    OUTPUTS = [OUTPUTS; out_decreasing]

    ## Saving outputs and plots
    savename = replace(replace(prob.name, r"[\/]" => "-"), "." => "_")
    savename = string(savename, "-exp2a")
    save("$(save_path)data/$(savename).jld", "OUTPUTS", OUTPUTS)

    pyplot()
    plot_outputs_Plots(OUTPUTS, prob, options, methodname="SVRG", suffix="-exp2a", path=save_path, legendpos=:topright, legendfont=8) # Plot and save output

end