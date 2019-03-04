"""
### "Optimal mini-batch and step sizes for SAGA", Nidham Gazagnadou, Robert M. Gower, Joseph Salmon (2019)

## --- EXPERIMENT 3 (serial implementation) ---
Goal: Comparing different classical settings of (single and mini-batch) SAGA and ours.

## --- THINGS TO CHANGE BEFORE RUNNING ---
- line 43: enter your full path to the "StochOpt.jl/" repository in the *path* variable

## --- HOW TO RUN THE CODE ---
To run only the first experiment (ijcnn1_full + column-scaling + lambda=1e-1), open a terminal, go into the "StochOpt.jl/" repository and run the following command:
>julia repeat_paper_experiments/repeat_optimal_minibatch_step_sizes_SAGA_paper_experiment_3.jl false
To launch all the 12 experiments of the paper change the bash input and run:
>julia repeat_paper_experiments/repeat_optimal_minibatch_step_sizes_SAGA_paper_experiment_3.jl true

## --- EXAMPLE OF RUNNING TIME ---
Running time of the first experiment on a laptop with 16Gb RAM and Intel® Core™ i7-8650U CPU @ 1.90GHz × 8
81.827728 seconds (263.18 M allocations: 33.242 GiB, 9.57% gc time), around 1min 22s
Running time of all 12 experiments on a laptop with 16Gb RAM and Intel® Core™ i7-8650U CPU @ 1.90GHz × 8
7768.175183 seconds (9.31 G allocations: 13.712 TiB, 15.83% gc time), around 2h 09min

## --- SAVED FILES ---
For each problem (data set + scaling process + regularization),
- the epoch and time plots (with and without Hofmann settings) are saved in ".pdf" format in the "./figures/" folder
- the results of the simulations (OUTPUTS objects) are saved in ".jld" format in the "./data/" folder
- the total complexities of the run methods are saved in ".txt" files the "./outputs/" folder
"""

## Bash input
allexperiments = parse(Bool, ARGS[1]); # run 1 (false) or all the 12 experiments (true)

using JLD
using Plots
using StatsBase
using Match
using Combinatorics
using Random # julia 0.7
using Printf # julia 0.7
using LinearAlgebra # julia 0.7
using Statistics # julia 0.7
using Base64 # julia 0.7
using Formatting
using LaTeXStrings

include("../src/StochOpt.jl")

#region
## Function used to the skip_error parameter
"""
    closest_power_of_ten(integer::Int64)

    Compute the closest power of ten of an integer.

#INPUTS:\\
    - **Int64** integer: integer\\
#OUTPUTS:\\
    - **Int64** or **Float64** closest_power: closest power of ten of the input

# Examples
```jldoctest
julia> closest_power(0)
1
julia> closest_power(9)
1
julia> closest_power(204)
100
```
"""
function closest_power_of_ten(integer::Int64)
    if integer < 0
        closest_power = 10.0 ^ (1 - length(string(integer)));
    else
        closest_power = 10 ^ (length(string(integer)) - 1);
    end
    return closest_power
end

## Function used to compute the best grid search step size for SAGA_nice
function calculate_best_stepsize_SAGA_nice(prob, options ; skip, max_time, rep_number, batchsize, grid)
    old_skip = options.skip_error_calculation;
    old_tol = options.tol;
    old_max_iter = options.max_iter;
    old_max_epocs = options.max_epocs;
    old_max_time = options.max_time;
    old_rep_number = options.rep_number;
    old_batchsize = options.batchsize;

    options.repeat_stepsize_calculation = true;
    options.rep_number = rep_number;
    options.skip_error_calculation = skip;
    # options.tol = 10.0^(-16);
    options.max_iter = 10^8;
    options.max_time = max_time;
    options.batchsize = batchsize;
    SAGA_nice = initiate_SAGA_nice(prob, options);
    output = minimizeFunc_grid_stepsize(prob, SAGA_nice, options, grid=grid);

    options.repeat_stepsize_calculation = false;
    options.skip_error_calculation = old_skip;
    options.tol = old_tol;
    options.max_iter = old_max_iter;
    options.max_epocs = old_max_epocs;
    options.max_time = old_max_time;
    options.rep_number = old_rep_number;
    options.batchsize = old_batchsize;
    return output
end
#endregion

## Experiments settings
default_path = "./data/";
numsimu = 1;                 # Increase the number of simulations to compute an average of the empiracal total complexity of each method
relaunch_gridsearch = false; # Change to true for recomputing the grid search on the step sizes

if allexperiments
    experiments = 1:12;
else
    experiments = 1:1;
end

datasets = ["ijcnn1_full", "ijcnn1_full", # scaled
            "YearPredictionMSD_full", "YearPredictionMSD_full", # scaled
            "covtype_binary", "covtype_binary", # scaled
            "slice", "slice", # scaled
            "slice", "slice", # unscaled
            "real-sim", "real-sim"]; # unscaled

scalings = ["column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "column-scaling", "column-scaling",
            "none", "none",
            "none", "none"];

lambdas = [10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3),
           10^(-1), 10^(-3)];

skip_errors = [[10^4 10 10 10^3], # ijcnn1_full + scaled + 1e-1                 : CHECKED
               [10^4 10^3 10^3 10^3], # ijcnn1_full + scaled + 1e-3             : CHECKED
               [10^4 10 10 10^4], # YearPredictionMSD_full + scaled + 1e-1      : CHECKED
               [10^4 10^3 10 10^4], # YearPredictionMSD_full + scaled + 1e-3    : CHECKED
               [10^5 10^2 10 10^5], # covtype_binary + scaled + 1e-1            : CHECKED
               [10^6 10^4 10^3 10^6], # covtype_binary + scaled + 1e-3          : CHECKED
               [10^4 10^3 10^3 10^4], # slice + scaled + 1e-1                   : CHECKED
               [10^5 10^5 10^5 10^5], # slice + scaled + 1e-3                   : CHECKED
               [10^4 10^2 10^2 10^2], # slice + unscaled + 1e-1                 : CHECKED
               [10^4 10^4 10^4 10^4], # slice + unscaled + 1e-3                 : CHECKED
               [10^4 1 1 10^3], # real-sim + unscaled + 1e-1                    : CHECKED
               [10^4 10 10 10^3] # real-sim + unscaled + 1e-3                   : CHECKED
              ];

@time begin
for exp in experiments
    data = datasets[exp];
    scaling = scalings[exp];
    lambda = lambdas[exp];
    skip_error = skip_errors[exp];
    println("EXPERIMENT : ", exp, " over ", length(experiments));
    @printf "Inputs: %s + %s + %1.1e \n" data scaling lambda;

    Random.seed!(1);

    ## Loading the data
    println("--- Loading data ---");
    X, y = loadDataset(default_path, data);

    ## Setting up the problem
    println("\n--- Setting up the selected problem ---");
    options = set_options(tol=10.0^(-4), max_iter=10^8, max_epocs=600,
                          max_time=60.0*60.0*5.0,
                          skip_error_calculation=10^5,
                          batchsize=1,
                          regularizor_parameter = "normalized",
                          initial_point="zeros", # is fixed not to add more randomness
                          force_continue=true); # force continue if diverging or if tolerance reached
    u = unique(y);
    if length(u) < 2
        error("Wrong number of possible outputs");
    elseif length(u) == 2
        println("Binary output detected: the problem is set to logistic regression")
        prob = load_logistic_from_matrices(X, y, data, options, lambda=lambda, scaling=scaling);
    else
        println("More than three modalities in the outputs: the problem is set to ridge regression")
        prob = load_ridge_regression(X, y, data, options, lambda=lambda, scaling=scaling);
    end

    X = nothing;
    y = nothing;

    n = prob.numdata;
    d = prob.numfeatures;
    mu = prob.mu
    Lmax = prob.Lmax;
    L = prob.L;

    if occursin("lgstc", prob.name)
        ## Correcting for logistic since phi'' <= 1/4
        Lmax /= 4;
    end

    ## Computing mini-batch and step sizes
    tau_defazio = 1;
    step_defazio = 1.0 / (3.0*(Lmax + n*mu));

    tau_hofmann = 20; # Hofmann : tau = 20, gamma = gamma(20)
    K = (4.0*tau_hofmann*Lmax) / (n*mu);
    step_hofmann = K / (2*Lmax*(1+K+sqrt(1+K^2)));

    tau_heuristic = round(Int, 1 + ( mu*(n-1) ) / ( 4*L ) );
    rho = ( n*(n - tau_heuristic) ) / ( tau_heuristic*(n-1) ); # Sketch residual
    rightterm = (rho / n)*Lmax + ( (mu*n) / (4*tau_heuristic) ); # Right-hand side term in the max
    heuristicbound = ( n*(tau_heuristic-1)*L + (n-tau_heuristic)*Lmax ) / ( tau_heuristic*(n-1) );
    step_heuristic = 0.25 / max(heuristicbound, rightterm);

    ## Calculating/Loading the best grid search step size for SAGA_nice with our optimal mini-batch size
    options.batchsize = tau_heuristic;
    if options.batchsize == 1
        method_name = "SAGA-nice";
    elseif options.batchsize > 1
        method_name = string("SAGA-", options.batchsize, "-nice");
    else
        error("Invalid batch size");
    end

    step_heuristic_gridsearch, = get_saved_stepsize(prob.name, method_name, options);
    if step_heuristic_gridsearch == 0.0 || relaunch_gridsearch
        grid = [2.0^(25), 2.0^(23), 2.0^(21), 2.0^(19), 2.0^(17), 2.0^(15), 2.0^(13), 2.0^(11),
                2.0^(9), 2.0^(7), 2.0^(5), 2.0^(3), 2.0^(1), 2.0^(-1), 2.0^(-3), 2.0^(-5),
                2.0^(-7), 2.0^(-9), 2.0^(-11), 2.0^(-13), 2.0^(-15), 2.0^(-17), 2.0^(-19),
                2.0^(-21), 2.0^(-23), 2.0^(-25), 2.0^(-27), 2.0^(-29), 2.0^(-31), 2.0^(-33)];
        nbskip = closest_power_of_ten(round.(Int, n ./ tau_heuristic ));
        output = calculate_best_stepsize_SAGA_nice(prob, options, skip=nbskip, max_time=180.0,
                                                   rep_number=5, batchsize=tau_heuristic, grid=grid);
        step_heuristic_gridsearch, = get_saved_stepsize(prob.name, method_name, options);
    end

    str_step_defazio = @sprintf "%.2e" step_defazio
    str_step_heuristic = @sprintf "%.2e" step_heuristic
    str_step_heuristic_gridsearch = @sprintf "%.2e" step_heuristic_gridsearch
    str_step_hofmann = @sprintf "%.2e" step_hofmann
    method_names = [latexstring("\$b_\\mathrm{Defazio} \\; \\; = 1 \\ \\ , \\gamma_\\mathrm{Defazio} \\ \\ \\: \\: = $str_step_defazio\$"),
                    latexstring("\$b_\\mathrm{practical} \\, = $tau_heuristic , \\gamma_\\mathrm{practical} \\ \\ = $str_step_heuristic\$"),
                    latexstring("\$b_\\mathrm{practical} \\, = $tau_heuristic , \\gamma_\\mathrm{grid search} = $str_step_heuristic_gridsearch\$"),
                    latexstring("\$b_\\mathrm{Hofmann} = 20 , \\gamma_\\mathrm{Hofmann}  \\ \\, = $str_step_hofmann\$")];
    mini_batch_sizes = [tau_defazio, tau_heuristic, tau_heuristic, tau_hofmann];
    stepsizes = [step_defazio, step_heuristic, step_heuristic_gridsearch, step_hofmann];

    ## Allowing user skip_error
    if skip_error == [0 0 0 0]
        skip_error = closest_power_of_ten.(round.(Int, n ./ (5*mini_batch_sizes) )); # around 5 points per epoch
    end
    println("---------------------------------- SKIP_ERROR ------------------------------------------");
    println(skip_error);
    println("----------------------------------------------------------------------------------------");

    println("------------------------------- MINI-BATCH SIZES ---------------------------------------");
    println(mini_batch_sizes);
    println("----------------------------------------------------------------------------------------");

    println("---------------------------------- STEP SIZES ------------------------------------------");
    println(stepsizes);
    println("----------------------------------------------------------------------------------------");

    ## SAGA 4 different runs (Defazio, our settings, grid search and Hofmann)
    itercomplex = zeros(length(stepsizes), numsimu);
    OUTPUTS = [];
    for idxmethod in 1:length(stepsizes)
        options.stepsize_multiplier = stepsizes[idxmethod];
        for idxsimu=1:numsimu
            println("\n----- Simulation #", idxsimu, " -----");
            options.skip_error_calculation = skip_error[idxmethod]; # skip error different for each tuple of mini-batch and step sizes
            options.batchsize = mini_batch_sizes[idxmethod];
            SAGA_nice = initiate_SAGA_nice(prob, options);
            println("Current method: ", method_names[idxmethod], ", mini-batch size = ", mini_batch_sizes[idxmethod],
                    ", step size = ", stepsizes[idxmethod]);
            output = minimizeFunc(prob, SAGA_nice, options, stop_at_tol=true, skip_decrease=false);
            println("---> Output fail = ", output.fail, "\n");
            itercomplex[idxmethod, idxsimu] = output.iterations;
            output.name = string(method_names[idxmethod]);
            OUTPUTS = [OUTPUTS; output];
        end
    end
    avg_itercomplex = mean(itercomplex, dims=2);
    avg_empcomplex = mini_batch_sizes .* avg_itercomplex;

    ## Computing the standard deviation of the measured total complexities if one runs more the experiments more than once
    if numsimu > 1
        empcomplex = mini_batch_sizes .* itercomplex;
        std_itercomplex = std(empcomplex, dims=2);
        ci_itercomplex = (1.96/sqrt(numsimu)) * std_itercomplex;
    else
        empcomplex = avg_empcomplex;
        ci_itercomplex = [0 0 0 0 0];
    end

    ## Saving the result of the simulations
    probname = replace(replace(prob.name, r"[\/]" => "-"), "." => "_");
    savename = string(probname, "-exp3-empcomplex-", numsimu, "-avg");
    save("$(default_path)$(savename).jld", "itercomplex", itercomplex, "empcomplex", empcomplex, "ci_itercomplex", ci_itercomplex,
         "OUTPUTS", OUTPUTS, "method_names", method_names, "skip_error", skip_error,
         "stepsizes", stepsizes, "mini_batch_sizes", mini_batch_sizes);

    ## Checking that all simulations reached tolerance
    fails = [OUTPUTS[i].fail for i=1:length(stepsizes)*numsimu];
    if all(s->(string(s)=="tol-reached"), fails)
        println("Tolerance always reached")
    end

    ## Plotting one SAGA-nice simulation for each mini-batch size
    if numsimu == 1
        # gr()
        pyplot()
        plot_outputs_Plots(OUTPUTS, prob, options, suffix="-exp3"); # Plot and save output epoch and time figures

        OUTPUTS_without_hofmann = OUTPUTS[1:3];
        pyplot()
        plot_outputs_Plots(OUTPUTS_without_hofmann, prob, options, suffix="_without_hofmann-exp3"); # Removing Hofmann settings curve from the plots
    end

    line1 =          "method name      | b_Defazio + step_Defazio | b_heuristic + step_heuristic | b_heuristic + step_gridsearch | b_Hofmann + step_Hofmann |\n"
    line2 = @sprintf "mini-batch size  |               %d               |             %d            |            %d            |               %d              |\n" mini_batch_sizes[1] mini_batch_sizes[2] mini_batch_sizes[3] mini_batch_sizes[4]
    line3 = @sprintf "step size        |         %e          |       %e       |       %e       |        %e        |\n" stepsizes[1] stepsizes[2] stepsizes[3] stepsizes[4]
    line4 = @sprintf "total complexity |             %s             |           %s            |         %s           |            %s             |\n" format(avg_empcomplex[1], commas=true) format(avg_empcomplex[2], commas=true) format(avg_empcomplex[3], commas=true) format(avg_empcomplex[4], commas=true)
    line5 = @sprintf "CI delta         |               %d             |           %d           |         %d           |         %d          |\n" ci_itercomplex[1] ci_itercomplex[2] ci_itercomplex[3] ci_itercomplex[4]

    println("--------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
    println(line1);
    println("--------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
    println(line2);
    println(line3);
    println(line4);
    println(line5);
    println("number of simulations: $numsimu\n\n");

    ## Saving the averaged empirical total complexities and the corresponding confidence intervals
    open("./outputs/$probname-exp3-complexity.txt", "a") do file
        write(file, "--------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
        write(file, line1);
        write(file, "--------------------------------------------------------------------------------------------------------------------------------------------------------------------\n");
        write(file, line2);
        write(file, line3);
        write(file, line4);
        write(file, line5);
        write(file, "number of simulations: $numsimu\n\n");
        write(file, "\n");
    end
end
end