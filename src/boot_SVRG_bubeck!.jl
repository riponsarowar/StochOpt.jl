"""
    initiate_SVRG_bubeck(prob, options ; numinneriters=0, probs=[])

Initiate the original SVRG method with option I, for b-nice or independent sampling.
It uniformly picks b data points out of n at each iteration to build an estimate of the gradient.

# INPUTS
- **Prob** prob: considered problem, e.g., logistic regression, ridge regression...
- **MyOptions** options: different options such as the mini-batch size, the stepsize multiplier...
- **Sampling** sampling: sampling object (b-nice or independent sampling)
- **Int64** numinneriters: size of the inner loop (twice the number of data samples n if set to 0)
# OUTPUTS
- **SVRG\\_bubeck\\_method** method: original SVRG method (option I) created by `initiate_SVRG_bubeck`

# REFERENCES
__Convex optimization: Algorithms and complexity__\\
Sebastien Bubeck\\
Foundations and Trends in Machine Learning. 2015.
"""
function initiate_SVRG_bubeck(prob::Prob, options::MyOptions, sampling::Sampling ; numinneriters::Int64=0)
    n = prob.numdata
    b = options.batchsize
    epocsperiter = b/n
    gradsperiter = b

    name = string("SVRG-vanilla-", sampling.name)

    stepmethod = descent_SVRG_bubeck!
    bootmethod = boot_SVRG_bubeck!
    reset = reset_SVRG_bubeck!

    stepsize = 0.0

    Lmax = prob.Lmax
    mu = prob.mu

    if numinneriters == -1
        numinneriters = 2*n # heuristic
    end
    reference_point = zeros(prob.numfeatures)
    new_reference_point = zeros(prob.numfeatures)
    reference_grad = zeros(prob.numfeatures)

    method = SVRG_bubeck_method(epocsperiter, gradsperiter, name, stepmethod, bootmethod, b, stepsize, Lmax, mu, numinneriters, reference_point, new_reference_point, reference_grad, reset, sampling)

    return method
end


"""
    boot_SVRG_bubeck!(prob, method, options)

Modify the method to set the stepsize based on the smoothness constants of the problem stored in **SVRG\\_bubeck\\_method** and possibly sets the number of skipped error calculation if not specfied such that 30 points are to be plotted.

# INPUTS
- **Prob** prob: considered problem, e.g., logistic regression, ridge regression...
- **SVRG\\_bubeck\\_method** method: original SVRG method (option I) created by `initiate_SVRG_bubeck`
- **MyOptions** options: different options such as the mini-batch size, the stepsize multiplier...
# OUTPUTS
- **NONE**
"""
function boot_SVRG_bubeck!(prob::Prob, method::SVRG_bubeck_method, options::MyOptions)
    if options.stepsize_multiplier > 0.0
        println("Manually set step size")
        method.stepsize = options.stepsize_multiplier
    elseif options.stepsize_multiplier == -1.0
        println("Automatically set SVRG step size")
        method.stepsize = 1/(10*method.Lmax)
        options.stepsize_multiplier = method.stepsize # /!\ Modifies the options
        println("Theoretical step size: ", method.stepsize)
    else
        error("Invalid options.stepsize_multiplier")
    end

    # WARNING: The following if statement does not seem to modify the method that is returned afterwards...
    if options.skip_error_calculation == 0.0
        options.skip_error_calculation = ceil(options.max_epocs*prob.numdata/(options.batchsize*30)) # show 30 points between 0 and the max number of epochs
        # 20 points over options.max_epocs when there are options.max_epocs *prob.numdata/(options.batchsize)) iterates in total
    end
    println("Skipping ", options.skip_error_calculation, " iterations per epoch\n")
end


"""
    reset_SVRG_bubeck(prob, method, options)

Reset the original SVRG method (option I), especially the step size, the point and gradient reference.

# INPUTS
- **Prob** prob: considered problem, e.g., logistic regression, ridge regression...
- **SVRG\\_bubeck\\_method** method: original SVRG method (option I) created by `initiate_SVRG_bubeck`
- **MyOptions** options: different options such as the mini-batch size, the stepsize multiplier...
# OUTPUTS
- **NONE**
"""
function reset_SVRG_bubeck!(prob::Prob, method::SVRG_bubeck_method, options::MyOptions)
    println("\n---- RESET SVRG VANILLA ----\n")

    method.batchsize = options.batchsize
    method.stepsize = options.stepsize_multiplier

    method.reference_point = zeros(prob.numfeatures)
    method.new_reference_point = zeros(prob.numfeatures)
    method.reference_grad = zeros(prob.numfeatures)
end